import json
import logging
from odoo import http
from odoo.http import request
from odoo.http.session import session_store
from odoo.exceptions import AccessError
from .base import BaseApiController

_logger = logging.getLogger(__name__)


class ProductApiController(BaseApiController):
    """Controller for LaundryFlow laundry service & product management APIs."""

    def _validate_and_serialize_product(self, product):
        """
        Validates a product.template record (or search_read dict) and serializes it
        for the Flutter client with required fields: id, sku, name, unit_price, uom, category, pricing_type.
        Explicitly rejects missing, empty, zero, or negative prices and missing/empty UoM
        without substituting fake defaults or empty strings.
        Returns tuple (is_valid, serialized_dict_or_error_info).
        """
        if isinstance(product, dict):
            prod_id = product.get('id')
            raw_name = product.get('name')
            raw_sku = product.get('default_code')
            raw_price = product.get('list_price')
            uom_raw = product.get('uom_id')
            if isinstance(uom_raw, (list, tuple)) and len(uom_raw) >= 2 and uom_raw[0]:
                uom_name = uom_raw[1] if isinstance(uom_raw[1], str) else None
            else:
                uom_name = None
            categ_raw = product.get('categ_id')
            if isinstance(categ_raw, (list, tuple)) and len(categ_raw) >= 2 and categ_raw[0]:
                categ_id = categ_raw[0]
                categ_name = categ_raw[1] if isinstance(categ_raw[1], str) else None
            else:
                categ_id = None
                categ_name = None
            raw_type = product.get('type')
            raw_active = product.get('active', True)
            raw_desc = product.get('description_sale') or product.get('description')
            curr_raw = product.get('currency_id')
            currency_name = (
                curr_raw[1].strip()
                if isinstance(curr_raw, (list, tuple)) and len(curr_raw) >= 2 and isinstance(curr_raw[1], str) and curr_raw[1].strip()
                else 'IDR'
            )
            has_image = bool(product.get('image_128'))
        else:
            prod_id = getattr(product, 'id', None)
            raw_name = getattr(product, 'name', None)
            raw_sku = getattr(product, 'default_code', None)
            raw_price = getattr(product, 'list_price', None)
            uom_rec = getattr(product, 'uom_id', None)
            if uom_rec and getattr(uom_rec, 'id', None):
                uom_name = getattr(uom_rec, 'name', None)
            else:
                uom_name = None
            categ_rec = getattr(product, 'categ_id', None)
            if categ_rec and getattr(categ_rec, 'id', None):
                categ_id = categ_rec.id
                categ_name = getattr(categ_rec, 'name', None)
            else:
                categ_id = None
                categ_name = None
            raw_type = getattr(product, 'type', None)
            raw_active = getattr(product, 'active', True)
            raw_desc = getattr(product, 'description_sale', None) or getattr(product, 'description', None)
            curr_rec = getattr(product, 'currency_id', None)
            currency_name = (
                curr_rec.name.strip()
                if curr_rec and getattr(curr_rec, 'id', None) and isinstance(getattr(curr_rec, 'name', None), str) and curr_rec.name.strip()
                else 'IDR'
            )
            has_image = bool(getattr(product, 'image_128', None))

        errors = []

        if not isinstance(prod_id, int) or isinstance(prod_id, bool) or prod_id <= 0:
            errors.append('ID produk tidak valid')

        if not isinstance(raw_name, str) or not raw_name.strip():
            errors.append('Nama produk (name) tidak boleh kosong')
            clean_name = None
        else:
            clean_name = raw_name.strip()

        if (
            raw_price is None
            or isinstance(raw_price, bool)
            or not isinstance(raw_price, (int, float))
        ):
            errors.append('Harga produk (list_price) harus berupa angka yang valid')
            unit_price = None
        else:
            price_float = float(raw_price)
            if price_float <= 0:
                errors.append('Harga produk (list_price) harus lebih besar dari 0')
                unit_price = None
            else:
                unit_price = int(price_float) if price_float.is_integer() else round(price_float, 2)

        if not isinstance(uom_name, str) or not uom_name.strip():
            errors.append('Satuan produk (uom_id) tidak valid atau belum diatur')
            clean_uom = None
        else:
            clean_uom = uom_name.strip()

        if raw_type != 'service':
            errors.append('Tipe produk harus berupa layanan (service)')

        if errors:
            return False, {
                'id': prod_id if isinstance(prod_id, int) and not isinstance(prod_id, bool) else None,
                'name': clean_name,
                'errors': errors,
                'reason': '; '.join(errors),
            }

        # Menentukan tipe perhitungan tarif (pricing_type) berdasarkan UoM
        clean_uom_lower = clean_uom.lower()
        if clean_uom_lower in ['kg', 'kilogram', 'g', 'gram']:
            pricing_type = 'weight'
        elif clean_uom_lower in ['m²', 'm2', 'meter persegi', 'sqm']:
            pricing_type = 'area'
        elif clean_uom_lower in ['set']:
            pricing_type = 'set'
        else:
            pricing_type = 'unit'

        clean_sku = raw_sku.strip() if isinstance(raw_sku, str) and raw_sku.strip() else None
        clean_categ = categ_name.strip() if isinstance(categ_name, str) and categ_name.strip() else None
        clean_desc = raw_desc.strip() if isinstance(raw_desc, str) and raw_desc.strip() else None
        image_url = f"/web/image/product.template/{prod_id}/image_128" if has_image else None

        return True, {
            'id': prod_id,
            'sku': clean_sku,
            'name': clean_name,
            'unit_price': unit_price,
            'uom': clean_uom,
            'category': clean_categ,
            'category_id': categ_id,
            'pricing_type': pricing_type,
            'description': clean_desc,
            'image': image_url,
            # Field kompatibilitas untuk aplikasi Flutter / client lama
            'price': unit_price,
            'unit': clean_uom,
            'service_name': clean_name,
            'type': 'service',
            'active': bool(raw_active),
            'currency': currency_name,
        }

    # Endpoint Daftar Produk & Layanan Laundry
    @http.route(
        [
            '/api/laundry/products',
            '/api/products',
        ],
        type='http',
        auth='public',
        methods=['GET', 'OPTIONS'],
        csrf=False
    )
    def get_products(self, **kwargs):
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            # 1. Autentikasi Pengguna
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.'
                }, status=401)

            # 2. Hak Akses (Authorization)
            try:
                request.env['product.template'].with_user(user).check_access('read')
            except AccessError:
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Anda tidak memiliki izin untuk melihat data produk.'
                }, status=403)

            # 3. Validasi Parameter Limit
            limit_raw = kwargs.get('limit') or request.params.get('limit')
            limit = 50
            if limit_raw is not None and str(limit_raw).strip() != '':
                try:
                    limit = int(limit_raw)
                    if limit <= 0:
                        return self._json_response({
                            'success': False,
                            'message': 'Parameter limit harus lebih besar dari 0'
                        }, status=400)
                    if limit > 100:
                        limit = 100
                except (ValueError, TypeError):
                    return self._json_response({
                        'success': False,
                        'message': 'Parameter limit harus berupa angka yang valid'
                    }, status=400)

            # 4. Domain Filter di Backend (Hanya layanan laundry aktif & dapat dijual)
            # Flutter tidak perlu mengirim ?type=service karena backend otomatis memfilter
            type_param = kwargs.get('type') or request.params.get('type')
            if type_param is not None and str(type_param).strip() != '':
                if str(type_param).strip() != 'service':
                    return self._json_response({
                        'success': False,
                        'message': 'Endpoint layanan laundry hanya mendukung produk bertipe service'
                    }, status=400)

            domain = [
                ('active', '=', True),
                ('type', '=', 'service'),
                ('sale_ok', '=', True),
            ]

            # Filter opsional berdasarkan kategori (category_id atau category)
            category_param = (
                kwargs.get('category_id')
                or request.params.get('category_id')
                or kwargs.get('category')
                or request.params.get('category')
            )
            if category_param is not None and str(category_param).strip() != '':
                cat_val = str(category_param).strip()
                if cat_val.isdigit():
                    domain.append(('categ_id', '=', int(cat_val)))
                else:
                    domain.append(('categ_id.name', 'ilike', cat_val))

            # Filter opsional berdasarkan pricing_type
            pricing_type_param = kwargs.get('pricing_type') or request.params.get('pricing_type')
            if pricing_type_param and isinstance(pricing_type_param, str) and pricing_type_param.strip():
                pt = pricing_type_param.strip().lower()
                if pt == 'weight':
                    domain.append(('uom_id.name', 'in', ['kg', 'g', 'gram']))
                elif pt == 'area':
                    domain.append(('uom_id.name', 'in', ['m²', 'm2']))
                elif pt == 'set':
                    domain.append(('uom_id.name', 'in', ['set']))
                elif pt == 'unit':
                    domain.append(('uom_id.name', 'in', ['pcs', 'unit', 'Units']))

            # Filter opsional berdasarkan nama atau SKU (q / query)
            q = kwargs.get('q') or request.params.get('q') or kwargs.get('query') or request.params.get('query')
            if q and isinstance(q, str) and q.strip():
                q_clean = q.strip()
                domain.extend(['|', ('name', 'ilike', q_clean), ('default_code', 'ilike', q_clean)])

            # 5. Ambil data melalui Odoo ORM (product.template)
            ProductTemplate = request.env['product.template'].with_user(user)
            products = ProductTemplate.search(
                domain,
                limit=limit,
                order='id asc, name asc'
            )

            if not products:
                return self._json_response({
                    'success': True,
                    'count': 0,
                    'data': []
                }, status=200)

            # 6. Validasi eksplisit setiap produk (tanpa nilai palsu / default kosong)
            data = []
            invalid_products = []
            for prod in products:
                is_valid, result_or_err = self._validate_and_serialize_product(prod)
                if is_valid:
                    data.append(result_or_err)
                else:
                    invalid_products.append(result_or_err)

            if invalid_products:
                first_err = invalid_products[0]
                prod_label = first_err.get('name') or f"ID {first_err.get('id')}"
                return self._json_response({
                    'success': False,
                    'message': f"Data produk '{prod_label}' tidak lengkap atau tidak valid: {first_err.get('reason')}",
                    'invalid_products': invalid_products,
                }, status=422)

            return self._json_response({
                'success': True,
                'count': len(data),
                'data': data
            }, status=200)

        except Exception as e:
            _logger.exception("Error fetching products: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan internal pada server'
            }, status=500)

    # Endpoint Detail & Update Produk & Layanan Laundry Berdasarkan ID
    @http.route(
        [
            '/api/laundry/products/<string:product_id>',
            '/api/products/<string:product_id>',
        ],
        type='http',
        auth='public',
        methods=['GET', 'PUT', 'PATCH', 'OPTIONS'],
        csrf=False
    )
    def handle_product_by_id(self, product_id=None, **kwargs):
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})
        elif request.httprequest.method in ['PUT', 'PATCH']:
            return self.update_product(product_id=product_id, **kwargs)
        else:
            return self.get_product_detail(product_id=product_id, **kwargs)

    def get_product_detail(self, product_id=None, **kwargs):
        try:
            # 1. Autentikasi Pengguna
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.'
                }, status=401)

            # 2. Hak Akses (Authorization)
            try:
                request.env['product.template'].with_user(user).check_access('read')
            except AccessError:
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Anda tidak memiliki izin untuk melihat data produk.'
                }, status=403)

            # 3. Validasi Parameter ID Produk
            try:
                pid = int(str(product_id).strip())
                if pid <= 0:
                    raise ValueError
            except (ValueError, TypeError):
                return self._json_response({
                    'success': False,
                    'message': 'ID produk harus berupa angka positif yang valid'
                }, status=400)

            # 4. Cari Layanan Laundry Aktif melalui Odoo ORM (hanya type='service' & sale_ok=True)
            product = request.env['product.template'].with_user(user).search([
                ('id', '=', pid),
                ('active', '=', True),
                ('type', '=', 'service'),
                ('sale_ok', '=', True),
            ], limit=1)

            if not product:
                return self._json_response({
                    'success': False,
                    'message': 'Data produk tidak ditemukan'
                }, status=404)

            # 5. Validasi eksplisit harga dan satuan produk
            is_valid, result_or_err = self._validate_and_serialize_product(product)
            if not is_valid:
                prod_label = result_or_err.get('name') or f"ID {pid}"
                return self._json_response({
                    'success': False,
                    'message': f"Data produk '{prod_label}' tidak lengkap atau tidak valid: {result_or_err.get('reason')}",
                    'invalid_products': [result_or_err],
                }, status=422)

            return self._json_response({
                'success': True,
                'data': result_or_err
            }, status=200)

        except Exception as e:
            _logger.exception("Error fetching product detail: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan internal pada server'
            }, status=500)

    def update_product(self, product_id=None, **kwargs):
        """
        PUT/PATCH /api/laundry/products/{id}
        Mengizinkan admin / manager untuk mengubah harga (list_price) atau atribut produk layanan laundry.
        """
        try:
            # 1. Autentikasi Pengguna
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.'
                }, status=401)

            # 2. Hak Akses (Authorization - write access)
            if not user.has_group('base.group_user'):
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Hanya admin atau staf yang berwenang mengubah harga produk.'
                }, status=403)

            try:
                request.env['product.template'].with_user(user).check_access('write')
            except AccessError:
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Anda tidak memiliki izin untuk memperbarui data produk.'
                }, status=403)

            # 3. Validasi ID Produk
            try:
                pid = int(str(product_id).strip())
                if pid <= 0:
                    raise ValueError
            except (ValueError, TypeError):
                return self._json_response({
                    'success': False,
                    'message': 'ID produk harus berupa angka positif yang valid'
                }, status=400)

            # 4. Cari Layanan Laundry
            product = request.env['product.template'].with_user(user).search([
                ('id', '=', pid),
                ('type', '=', 'service'),
            ], limit=1)

            if not product:
                return self._json_response({
                    'success': False,
                    'message': 'Data produk tidak ditemukan atau bukan merupakan layanan laundry'
                }, status=404)

            # 5. Parse JSON Body
            try:
                raw_body = request.httprequest.data
                payload = json.loads(raw_body.decode('utf-8')) if raw_body else {}
            except Exception:
                payload = request.params

            vals = {}

            # Edit Harga (price / list_price / unit_price)
            price_val = None
            if 'price' in payload:
                price_val = payload['price']
            elif 'list_price' in payload:
                price_val = payload['list_price']
            elif 'unit_price' in payload:
                price_val = payload['unit_price']

            if price_val is not None:
                try:
                    p_float = float(price_val)
                    if p_float <= 0:
                        return self._json_response({
                            'success': False,
                            'message': 'Harga produk harus berupa angka lebih besar dari 0'
                        }, status=400)
                    vals['list_price'] = p_float
                except (ValueError, TypeError):
                    return self._json_response({
                        'success': False,
                        'message': 'Format harga produk tidak valid'
                    }, status=400)

            # Edit Nama Produk (opsional)
            if 'name' in payload and payload['name'] is not None:
                clean_name = str(payload['name']).strip()
                if not clean_name:
                    return self._json_response({
                        'success': False,
                        'message': 'Nama produk tidak boleh kosong'
                    }, status=400)
                vals['name'] = clean_name

            # Edit Deskripsi (opsional)
            if 'description' in payload and payload['description'] is not None:
                vals['description_sale'] = str(payload['description']).strip()

            # Edit Status Aktif / Sale OK (opsional)
            if 'active' in payload and payload['active'] is not None:
                vals['active'] = bool(payload['active'])
            if 'sale_ok' in payload and payload['sale_ok'] is not None:
                vals['sale_ok'] = bool(payload['sale_ok'])

            if not vals:
                return self._json_response({
                    'success': False,
                    'message': 'Tidak ada perubahan data yang dikirimkan.'
                }, status=400)

            # Update via Odoo ORM
            product.write(vals)

            # Serialisasi hasil pembaruan
            is_valid, result_or_err = self._validate_and_serialize_product(product)
            return self._json_response({
                'success': True,
                'message': 'Data produk berhasil diperbarui',
                'data': result_or_err
            }, status=200)

        except Exception as e:
            _logger.exception("Error updating product %s: %s", product_id, str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan internal pada server'
            }, status=500)
