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
        for the Flutter client with required fields: id, name, unit_price, uom.
        Explicitly rejects missing, empty, zero, or negative prices and missing/empty UoM
        without substituting fake defaults or empty strings.
        Returns tuple (is_valid, serialized_dict_or_error_info).
        """
        if isinstance(product, dict):
            prod_id = product.get('id')
            raw_name = product.get('name')
            raw_price = product.get('list_price')
            uom_raw = product.get('uom_id')
            if isinstance(uom_raw, (list, tuple)) and len(uom_raw) >= 2 and uom_raw[0]:
                uom_name = uom_raw[1] if isinstance(uom_raw[1], str) else None
            else:
                uom_name = None
            raw_type = product.get('type')
            raw_active = product.get('active', True)
            curr_raw = product.get('currency_id')
            currency_name = (
                curr_raw[1].strip()
                if isinstance(curr_raw, (list, tuple)) and len(curr_raw) >= 2 and isinstance(curr_raw[1], str) and curr_raw[1].strip()
                else 'IDR'
            )
        else:
            prod_id = getattr(product, 'id', None)
            raw_name = getattr(product, 'name', None)
            raw_price = getattr(product, 'list_price', None)
            uom_rec = getattr(product, 'uom_id', None)
            if uom_rec and getattr(uom_rec, 'id', None):
                uom_name = getattr(uom_rec, 'name', None)
            else:
                uom_name = None
            raw_type = getattr(product, 'type', None)
            raw_active = getattr(product, 'active', True)
            curr_rec = getattr(product, 'currency_id', None)
            currency_name = (
                curr_rec.name.strip()
                if curr_rec and getattr(curr_rec, 'id', None) and isinstance(getattr(curr_rec, 'name', None), str) and curr_rec.name.strip()
                else 'IDR'
            )

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

        return True, {
            'id': prod_id,
            'name': clean_name,
            'unit_price': unit_price,
            'uom': clean_uom,
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

            # Filter opsional berdasarkan nama (q / query)
            q = kwargs.get('q') or request.params.get('q') or kwargs.get('query') or request.params.get('query')
            if q and isinstance(q, str) and q.strip():
                domain.append(('name', 'ilike', q.strip()))

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

    # Endpoint Detail Produk & Layanan Laundry Berdasarkan ID
    @http.route(
        [
            '/api/laundry/products/<string:product_id>',
            '/api/products/<string:product_id>',
        ],
        type='http',
        auth='public',
        methods=['GET', 'OPTIONS'],
        csrf=False
    )
    def get_product_detail(self, product_id=None, **kwargs):
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
