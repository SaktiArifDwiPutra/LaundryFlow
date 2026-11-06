import json
import logging
from odoo import http
from odoo.http import request
from odoo.http.session import session_store
from odoo.exceptions import ValidationError, AccessError, UserError
from .base import BaseApiController

_logger = logging.getLogger(__name__)


class OrderApiController(BaseApiController):
    """
    API Controller untuk opsi pesanan, kecepatan pengerjaan, dan pembuatan order LaundryFlow.
    Memenuhi Ketentuan Tugas 7:
    - Opsi pengerjaan: Reguler dan Same Day Service
    - Ketersediaan Same Day dapat dikonfigurasi admin
    - Menolak Same Day jika sedang tidak tersedia
    - Biaya tambahan diambil dari konfigurasi Odoo jika sudah dikonfirmasi
    """

    @classmethod
    def _compute_order_stages_and_next(cls, order):
        """Menghitung daftar tahapan workflow (stages) dan status berikutnya (next_status) untuk pesanan tertentu."""
        if order.state == 'cancelled':
            return [], None
        pipeline = order._get_process_pipeline() if hasattr(order, '_get_process_pipeline') else ['washing', 'drying', 'ironing']
        delivery = getattr(order, 'delivery_type', 'pickup') or "pickup"
        stages = ["received"] + pipeline + ["ready"]
        if delivery == "delivery":
            stages.append("out_for_delivery")
        stages.append("completed")
        next_status = None
        if order.state in stages:
            idx = stages.index(order.state)
            if idx + 1 < len(stages):
                next_status = stages[idx + 1]
        return stages, next_status

    @http.route(
        [
            '/api/laundry/service-speeds',
            '/api/laundry/orders/options',
            '/api/orders/options',
        ],
        type='http',
        auth='public',
        methods=['GET', 'OPTIONS'],
        csrf=False,
    )
    def get_service_speeds(self, **kwargs):
        """
        Mengembalikan daftar pilihan kecepatan pengerjaan yang tersedia untuk aplikasi klien (Flutter).
        """
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.',
                }, status=401)

            order_model = request.env['laundry.order'].with_user(user)
            speeds = order_model.get_available_service_speeds()

            return self._json_response({
                'success': True,
                'count': len(speeds),
                'data': speeds,
            }, status=200)

        except Exception as e:
            _logger.exception("Error in get_service_speeds: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server.',
            }, status=500)

    @http.route(
        [
            '/api/laundry/orders',
            '/api/orders',
        ],
        type='http',
        auth='public',
        methods=['GET', 'POST', 'OPTIONS'],
        csrf=False,
    )
    def handle_orders(self, **kwargs):
        """
        Handler routing untuk pesanan laundry:
        - GET: Mengembalikan daftar pesanan (list orders)
        - POST: Membuat transaksi pesanan baru
        - OPTIONS: CORS preflight
        """
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})
        elif request.httprequest.method == 'POST':
            return self.create_order(**kwargs)
        else:
            return self.get_orders(**kwargs)

    def get_orders(self, **kwargs):
        """
        GET /api/laundry/orders
        Mengembalikan daftar transaksi pesanan laundry dengan filter opsional:
        partner_id, state, service_speed, limit, dan offset.
        """
        try:
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.',
                }, status=401)

            domain = []

            # Filter partner_id jika dikirim atau jika user adalah portal/customer
            partner_param = kwargs.get('partner_id') or request.params.get('partner_id')
            if partner_param:
                try:
                    domain.append(('partner_id', '=', int(partner_param)))
                except (ValueError, TypeError):
                    pass
            elif user.has_group('base.group_portal'):
                domain.append(('partner_id', '=', user.partner_id.id))

            # Filter state (received, washing, ironing, ready, completed, cancelled)
            state_param = kwargs.get('state') or request.params.get('state')
            if state_param and str(state_param).strip():
                domain.append(('state', '=', str(state_param).strip()))

            # Filter service_speed (regular, same_day)
            speed_param = kwargs.get('service_speed') or request.params.get('service_speed')
            if speed_param and str(speed_param).strip():
                domain.append(('service_speed', '=', str(speed_param).strip()))

            # Filter pencarian teks bebas (q: nomor order, nama pelanggan, nomor WhatsApp)
            q_param = kwargs.get('q') or request.params.get('q')
            if q_param and str(q_param).strip():
                q_clean = str(q_param).strip()
                domain.append('|')
                domain.append(('name', 'ilike', q_clean))
                domain.append('|')
                domain.append(('partner_id.name', 'ilike', q_clean))
                domain.append(('whatsapp_phone', 'ilike', q_clean))

            # Pagination
            limit = 50
            limit_raw = kwargs.get('limit') or request.params.get('limit')
            if limit_raw:
                try:
                    l = int(limit_raw)
                    if 0 < l <= 100:
                        limit = l
                except (ValueError, TypeError):
                    pass

            offset = 0
            offset_raw = kwargs.get('offset') or request.params.get('offset')
            if offset_raw:
                try:
                    o = int(offset_raw)
                    if o >= 0:
                        offset = o
                except (ValueError, TypeError):
                    pass

            orders = request.env['laundry.order'].with_user(user).search(
                domain,
                order='order_date desc, id desc',
                limit=limit,
                offset=offset
            )

            data = []
            for order in orders:
                stages, next_status = self._compute_order_stages_and_next(order)
                partner_phone = getattr(order.partner_id, 'phone', None) or getattr(order.partner_id, 'mobile', None) or order.whatsapp_phone or ''
                data.append({
                    'id': order.id,
                    'name': order.name,
                    'order_date': order.order_date.isoformat() if order.order_date else None,
                    'partner_id': order.partner_id.id,
                    'partner_name': order.partner_id.name,
                    'partner_phone': partner_phone,
                    'delivery_type': getattr(order, 'delivery_type', 'pickup') or 'pickup',
                    'delivery_fee': float(getattr(order, 'delivery_fee', 0.0) or 0.0),
                    'service_speed': order.service_speed,
                    'service_speed_fee': float(order.service_speed_fee or 0.0),
                    'weight': float(order.weight or 0.0),
                    'total_amount': float(order.total_amount or 0.0),
                    'state': order.state,
                    'stages': stages,
                    'next_status': next_status,
                    'notes': order.notes or '',
                    'whatsapp_status': order.whatsapp_status,
                    'whatsapp_phone': order.whatsapp_phone,
                    'whatsapp_sent': bool(order.whatsapp_sent),
                    'payment_status': getattr(order, 'payment_status', 'unpaid') or 'unpaid',
                    'payment_method': getattr(order, 'payment_method', None) or None,
                    'amount_paid': float(getattr(order, 'amount_paid', 0.0) or 0.0),
                    'amount_due': float(getattr(order, 'amount_due', 0.0) or 0.0),
                    'lines_count': len(order.line_ids),
                })

            return self._json_response({
                'success': True,
                'count': len(data),
                'data': data
            }, status=200)

        except Exception as e:
            _logger.exception("Error in get_orders: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server.',
            }, status=500)

    def create_order(self, **kwargs):
        """
        Membuat transaksi pesanan laundry dengan validasi lengkap business logic:
        - Satu atau multi-layanan (kg, pcs, set, karpet m²)
        - Validasi kuantitas tidak boleh nol atau negatif
        - Validasi panjang dan lebar karpet harus positif (> 0)
        - Validasi kecocokan UoM
        - Snapshot harga katalog Odoo saat transaksi dibuat
        - Mengabaikan manipulasi harga/total dari client (seluruhnya dihitung ulang di backend)
        - Opsi kecepatan: Reguler atau Same Day Service
        - Validasi ketersediaan dan surcharge Same Day
        """
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.',
                }, status=401)

            try:
                raw_data = request.httprequest.data
                body = json.loads(raw_data.decode('utf-8')) if raw_data else {}
            except Exception:
                return self._json_response({
                    'success': False,
                    'message': 'Format JSON payload tidak valid.',
                }, status=400)

            partner_id = body.get('partner_id') or body.get('customer_id')
            if not partner_id:
                return self._json_response({
                    'success': False,
                    'message': 'Pelanggan (partner_id) wajib diisi.',
                }, status=400)

            try:
                pid = int(partner_id)
            except (ValueError, TypeError):
                return self._json_response({
                    'success': False,
                    'message': 'ID pelanggan (partner_id) harus berupa angka yang valid.',
                }, status=400)

            partner = request.env['res.partner'].with_user(user).browse(pid)
            if not partner.exists():
                return self._json_response({
                    'success': False,
                    'message': f'Pelanggan dengan ID {pid} tidak ditemukan.',
                }, status=404)

            # Validasi hak akses portal: pelanggan hanya boleh membuat order untuk dirinya sendiri
            if user.has_group('base.group_portal') and user.partner_id.id != pid:
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Anda hanya dapat membuat pesanan untuk akun Anda sendiri.',
                }, status=403)

            speed = body.get('service_speed') or body.get('priority') or 'regular'
            if speed == 'express':
                speed = 'same_day'

            if speed not in ('regular', 'same_day'):
                return self._json_response({
                    'success': False,
                    'message': f"Pilihan jenis pengerjaan '{speed}' tidak valid. Pilihan yang tersedia: Reguler (regular) atau Same Day Service (same_day).",
                }, status=400)

            order_model = request.env['laundry.order'].with_user(user)
            if speed == 'same_day' and not order_model.is_same_day_available():
                return self._json_response({
                    'success': False,
                    'message': 'Layanan Same Day Service sedang tidak tersedia saat ini.',
                }, status=400)

            lines_data = body.get('lines') or body.get('line_ids') or []
            if not lines_data or not isinstance(lines_data, list):
                return self._json_response({
                    'success': False,
                    'message': 'Detail layanan (lines) wajib diisi minimal satu baris.',
                }, status=400)

            order_lines = []
            line_model = request.env['laundry.order.line']

            for idx, line in enumerate(lines_data):
                if not isinstance(line, dict):
                    return self._json_response({
                        'success': False,
                        'message': f'Format data baris ke-{idx+1} tidak valid.',
                    }, status=400)

                prod_id = line.get('product_template_id') or line.get('product_id')
                if not prod_id:
                    return self._json_response({
                        'success': False,
                        'message': f'ID produk layanan (product_id) wajib diisi pada baris ke-{idx+1}.',
                    }, status=400)

                try:
                    prod_id = int(prod_id)
                except (ValueError, TypeError):
                    return self._json_response({
                        'success': False,
                        'message': f'ID produk layanan {prod_id} harus berupa angka yang valid.',
                    }, status=400)

                tmpl = request.env['product.template'].with_user(user).browse(prod_id)
                if not tmpl.exists() or tmpl.type != 'service':
                    return self._json_response({
                        'success': False,
                        'message': f"Produk dengan ID {prod_id} tidak ditemukan atau bukan merupakan layanan laundry.",
                    }, status=404 if not tmpl.exists() else 400)

                pricing_type = line_model._determine_pricing_type(tmpl.uom_id.name)

                # Validasi kuantitas tidak boleh negatif dan tidak boleh nol
                qty_raw = line.get('quantity') if 'quantity' in line else line.get('qty')
                if qty_raw is not None:
                    try:
                        qty = float(qty_raw)
                    except (ValueError, TypeError):
                        return self._json_response({
                            'success': False,
                            'message': f'Kuantitas layanan pada baris ke-{idx+1} harus berupa angka yang valid.',
                        }, status=400)
                    if qty <= 0:
                        return self._json_response({
                            'success': False,
                            'message': 'Kuantitas atau berat layanan harus berupa angka positif lebih dari 0.',
                        }, status=400)
                else:
                    qty = 1.0

                # Validasi dimensi karpet (m²)
                length_val = 0.0
                width_val = 0.0
                if pricing_type == 'area':
                    length_raw = line.get('length')
                    width_raw = line.get('width')
                    if length_raw is None or width_raw is None:
                        return self._json_response({
                            'success': False,
                            'message': 'Layanan karpet wajib menyertakan ukuran panjang (length) dan lebar (width).',
                        }, status=400)
                    try:
                        length_val = float(length_raw)
                        width_val = float(width_raw)
                    except (ValueError, TypeError):
                        return self._json_response({
                            'success': False,
                            'message': 'Panjang dan lebar karpet harus berupa angka yang valid.',
                        }, status=400)

                    if length_val <= 0:
                        return self._json_response({
                            'success': False,
                            'message': 'Detail karpet wajib memiliki panjang berupa angka positif lebih dari 0 meter.',
                        }, status=400)
                    if width_val <= 0:
                        return self._json_response({
                            'success': False,
                            'message': 'Detail karpet wajib memiliki lebar berupa angka positif lebih dari 0 meter.',
                        }, status=400)

                # Validasi UoM jika ditentukan di request
                uom_id = None
                uom_param = line.get('uom_id') or line.get('uom')
                if uom_param:
                    if isinstance(uom_param, int) or (isinstance(uom_param, str) and uom_param.isdigit()):
                        uom_rec = request.env['uom.uom'].with_user(user).browse(int(uom_param))
                    elif isinstance(uom_param, str):
                        uom_rec = request.env['uom.uom'].with_user(user).search([('name', '=', uom_param.strip())], limit=1)
                    else:
                        uom_rec = None

                    if not uom_rec or not uom_rec.exists():
                        return self._json_response({
                            'success': False,
                            'message': f"Satuan '{uom_param}' tidak ditemukan di sistem.",
                        }, status=400)

                    # Cek kompatibilitas UoM
                    if uom_rec.id != tmpl.uom_id.id:
                        line_root = line_model._get_uom_category_or_root(uom_rec)
                        prod_root = line_model._get_uom_category_or_root(tmpl.uom_id)
                        if line_root != prod_root:
                            return self._json_response({
                                'success': False,
                                'message': f"Satuan '{uom_rec.name}' tidak kompatibel dengan produk layanan '{tmpl.name}'.",
                            }, status=400)
                    uom_id = uom_rec.id
                else:
                    uom_id = tmpl.uom_id.id

                # Snapshot harga satuan langsung dari katalog Odoo (mengabaikan manipulasi harga client)
                order_lines.append((0, 0, {
                    'product_template_id': tmpl.id,
                    'price_unit': tmpl.list_price,
                    'uom_id': uom_id,
                    'quantity': qty,
                    'length': length_val,
                    'width': width_val,
                    'item_details': line.get('item_details', ''),
                    'notes': line.get('notes', ''),
                }))

            # 8. Opsi Pengambilan & Pengantaran (Fulfillment: pickup vs delivery)
            delivery_type_input = str(body.get('delivery_type') or body.get('fulfillment') or 'pickup').strip().lower()
            if delivery_type_input not in ['pickup', 'delivery']:
                delivery_type_input = 'pickup'

            delivery_address_input = body.get('delivery_address') or ''
            delivery_fee_input = 0.0
            if delivery_type_input == 'delivery':
                try:
                    delivery_fee_input = max(0.0, float(body.get('delivery_fee') or 0.0))
                except (ValueError, TypeError):
                    delivery_fee_input = 0.0

            vals = {
                'partner_id': pid,
                'service_speed': speed,
                'delivery_type': delivery_type_input,
                'delivery_address': delivery_address_input,
                'delivery_fee': delivery_fee_input,
                'notes': body.get('notes', ''),
                'item_details': body.get('item_details', ''),
                'user_id': user.id,
                'line_ids': order_lines,
            }

            try:
                order = order_model.create(vals)
            except ValidationError as ve:
                return self._json_response({
                    'success': False,
                    'message': str(ve),
                }, status=400)

            # Format rincian lengkap pesanan yang baru dibuat
            lines_resp = []
            for ol in order.line_ids:
                lines_resp.append({
                    'id': ol.id,
                    'product_id': ol.product_template_id.id,
                    'product_name': ol.product_template_id.name,
                    'pricing_type': ol.pricing_type,
                    'uom': ol.uom_id.name if ol.uom_id else '',
                    'quantity': ol.quantity,
                    'weight': ol.weight,
                    'length': ol.length,
                    'width': ol.width,
                    'area': ol.area,
                    'price_unit': ol.price_unit,
                    'subtotal': ol.subtotal,
                    'item_details': ol.item_details or '',
                })

            stages, next_status = self._compute_order_stages_and_next(order)
            partner_phone = getattr(order.partner_id, 'phone', None) or getattr(order.partner_id, 'mobile', None) or order.whatsapp_phone or ''
            partner_address = order.partner_id.contact_address or ''
            delivery_address = getattr(order, 'delivery_address', None) or partner_address

            return self._json_response({
                'success': True,
                'message': 'Pesanan berhasil dibuat.',
                'data': {
                    'id': order.id,
                    'name': order.name,
                    'order_date': order.order_date.isoformat() if order.order_date else None,
                    'partner_id': order.partner_id.id,
                    'partner_name': order.partner_id.name,
                    'partner_phone': partner_phone,
                    'partner_address': partner_address,
                    'delivery_type': getattr(order, 'delivery_type', 'pickup') or 'pickup',
                    'delivery_address': delivery_address,
                    'delivery_fee': float(getattr(order, 'delivery_fee', 0.0) or 0.0),
                    'service_speed': order.service_speed,
                    'service_speed_fee': order.service_speed_fee,
                    'weight': order.weight,
                    'total_amount': order.total_amount,
                    'state': order.state,
                    'stages': stages,
                    'next_status': next_status,
                    'notes': order.notes or '',
                    'lines': lines_resp,
                }
            }, status=201)

        except Exception as e:
            _logger.exception("Error in create_order: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server.',
            }, status=500)

    @http.route(
        [
            '/api/laundry/orders/<int:order_id>',
            '/api/orders/<int:order_id>',
        ],
        type='http',
        auth='public',
        methods=['GET', 'OPTIONS'],
        csrf=False,
    )
    def get_order_detail(self, order_id, **kwargs):
        """
        Mengembalikan rincian lengkap satu transaksi pesanan laundry beserta detail item,
        satuan, snapshot harga satuan, luas karpet (m²), subtotal, dan total pesanan.
        """
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.',
                }, status=401)

            order = request.env['laundry.order'].with_user(user).browse(order_id)
            if not order.exists():
                return self._json_response({
                    'success': False,
                    'message': f'Pesanan dengan ID {order_id} tidak ditemukan.',
                }, status=404)

            lines_data = []
            for line in order.line_ids:
                lines_data.append({
                    'id': line.id,
                    'product_id': line.product_template_id.id,
                    'product_name': line.product_template_id.name,
                    'pricing_type': line.pricing_type,
                    'uom': line.uom_id.name if line.uom_id else '',
                    'weight': line.weight,
                    'quantity': line.quantity,
                    'length': line.length,
                    'width': line.width,
                    'area': line.area,
                    'price_unit': line.price_unit,
                    'subtotal': line.subtotal,
                    'item_details': line.item_details or '',
                })

            stages, next_status = self._compute_order_stages_and_next(order)
            partner_phone = getattr(order.partner_id, 'phone', None) or getattr(order.partner_id, 'mobile', None) or order.whatsapp_phone or ''
            partner_address = order.partner_id.contact_address or ''
            delivery_address = getattr(order, 'delivery_address', None) or partner_address

            return self._json_response({
                'success': True,
                'data': {
                    'id': order.id,
                    'name': order.name,
                    'order_date': order.order_date.isoformat() if order.order_date else None,
                    'partner_id': order.partner_id.id,
                    'partner_name': order.partner_id.name,
                    'partner_phone': partner_phone,
                    'partner_address': partner_address,
                    'delivery_type': getattr(order, 'delivery_type', 'pickup') or 'pickup',
                    'delivery_address': delivery_address,
                    'delivery_fee': float(getattr(order, 'delivery_fee', 0.0) or 0.0),
                    'service_speed': order.service_speed,
                    'service_speed_fee': order.service_speed_fee,
                    'weight': order.weight,
                    'total_amount': order.total_amount,
                    'state': order.state,
                    'stages': stages,
                    'next_status': next_status,
                    'notes': order.notes or '',
                    'whatsapp_status': order.whatsapp_status,
                    'whatsapp_phone': order.whatsapp_phone,
                    'whatsapp_sent': bool(order.whatsapp_sent),
                    'whatsapp_last_sent': order.whatsapp_last_sent.strftime('%Y-%m-%d %H:%M:%S') if order.whatsapp_last_sent else None,
                    'payment_status': getattr(order, 'payment_status', 'unpaid') or 'unpaid',
                    'payment_method': getattr(order, 'payment_method', None) or None,
                    'amount_paid': float(getattr(order, 'amount_paid', 0.0) or 0.0),
                    'amount_due': float(getattr(order, 'amount_due', 0.0) or 0.0),
                    'change_amount': float(getattr(order, 'change_amount', 0.0) or 0.0),
                    'payment_date': order.payment_date.strftime('%Y-%m-%d %H:%M:%S') if getattr(order, 'payment_date', None) else None,
                    'payment_reference': getattr(order, 'payment_reference', None) or None,
                    'lines': lines_data,
                }
            }, status=200)

        except Exception as e:
            _logger.exception("Error in get_order_detail: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server.',
            }, status=500)

    @http.route(
        [
            '/api/laundry/orders/<int:order_id>/status',
            '/api/orders/<int:order_id>/status',
        ],
        type='http',
        auth='public',
        methods=['PATCH', 'OPTIONS'],
        csrf=False,
    )
    def update_order_status(self, order_id, **kwargs):
        """
        PATCH /api/laundry/orders/<int:order_id>/status
        Endpoint untuk memperbarui status pesanan memanfaatkan method workflow (Task 2):
        - washing -> action_washing()
        - drying -> action_drying()
        - ironing -> action_ironing()
        - ready -> action_ready()
        - out_for_delivery -> action_out_for_delivery()
        - completed -> action_complete()
        - cancelled -> action_cancel()

        Ketentuan:
        - Autentikasi dan otorisasi: hanya admin/operator (internal users), portal dilarang (HTTP 403).
        - Menolak direct state write: client memanggil method workflow via API ini.
        - HTTP 404 jika order_id tidak ditemukan.
        - HTTP 400 jika payload/parameter 'to' tidak valid atau tidak dikenal.
        - HTTP 409 Conflict jika status tujuan melompati tahapan wajib atau tidak sah.
        - Mengembalikan response JSON informatif dengan data: id, order_number, previous_status,
          current_status, next_status, dan stages.
        """
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        STATUS_ACTION_MAP = {
            'washing': 'action_washing',
            'drying': 'action_drying',
            'ironing': 'action_ironing',
            'ready': 'action_ready',
            'out_for_delivery': 'action_out_for_delivery',
            'completed': 'action_complete',
            'cancelled': 'action_cancel',
        }

        try:
            # 1. Autentikasi
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.',
                }, status=401)

            # 2. Otorisasi (hanya admin / operator internal, portal/customer dilarang)
            if user.has_group('base.group_portal') or not user.has_group('base.group_user'):
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Hanya admin atau operator yang berwenang memperbarui status pesanan.',
                }, status=403)

            # 3. Parse JSON Body
            try:
                raw_data = request.httprequest.data
                body = json.loads(raw_data.decode('utf-8')) if raw_data else {}
            except Exception:
                return self._json_response({
                    'success': False,
                    'message': 'Format JSON payload tidak valid.',
                }, status=400)

            target_status = (body.get('to') or body.get('status') or '').strip().lower()
            if not target_status:
                return self._json_response({
                    'success': False,
                    'message': "Parameter 'to' wajib diisi dengan status tujuan pesanan.",
                }, status=400)

            if target_status not in STATUS_ACTION_MAP:
                valid_options = ", ".join(STATUS_ACTION_MAP.keys())
                return self._json_response({
                    'success': False,
                    'message': f"Status tujuan '{target_status}' tidak dikenal. Pilihan yang valid: {valid_options}.",
                }, status=400)

            # 4. Ambil order dengan row-level lock untuk menghindari race conditions concurrency
            request.env.cr.execute("SELECT id FROM laundry_order WHERE id = %s FOR UPDATE", [order_id])

            order = request.env['laundry.order'].with_user(user).browse(order_id)
            if not order.exists():
                return self._json_response({
                    'success': False,
                    'message': f"Pesanan dengan ID {order_id} tidak ditemukan.",
                }, status=404)

            action_name = STATUS_ACTION_MAP[target_status]
            action_method = getattr(order, action_name, None)
            if not action_method:
                return self._json_response({
                    'success': False,
                    'message': f"Method transisi '{action_name}' tidak ditemukan pada model pesanan.",
                }, status=500)

            previous_status = order.state

            # 5. Eksekusi transisi status melalui workflow method (menangani ValidationError -> HTTP 409)
            try:
                action_method()
            except (ValidationError, UserError) as ve:
                return self._json_response({
                    'success': False,
                    'message': str(ve).replace('\n', ' '),
                }, status=409)

            # 6. Hitung pipeline tahapan dan status berikutnya (next_status)
            pipeline = order._get_process_pipeline()
            delivery = order.delivery_type or "pickup"

            stages = ["received"] + pipeline + ["ready"]
            if delivery == "delivery":
                stages.append("out_for_delivery")
            stages.append("completed")

            next_status = None
            if order.state in stages:
                idx = stages.index(order.state)
                if idx + 1 < len(stages):
                    next_status = stages[idx + 1]

            return self._json_response({
                'success': True,
                'message': 'Status pesanan berhasil diperbarui.',
                'data': {
                    'id': order.id,
                    'order_number': order.name,
                    'previous_status': previous_status,
                    'current_status': order.state,
                    'next_status': next_status,
                    'stages': stages,
                }
            }, status=200)

        except Exception as e:
            _logger.exception("Error in update_order_status: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server.',
            }, status=500)

    @http.route(
        [
            '/api/orders/<int:order_id>/send-whatsapp',
            '/api/laundry/orders/<int:order_id>/send-whatsapp',
        ],
        type='http',
        auth='public',
        methods=['POST', 'OPTIONS'],
        csrf=False,
    )
    def send_order_whatsapp(self, order_id, **kwargs):
        """
        Mengirim notifikasi WhatsApp untuk pesanan tertentu (manual trigger atau kirim ulang nota/info).
        Mendukung pilihan template: 'invoice', 'ready', 'reminder', dan 'custom'.
        """
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            # 1. Autentikasi Pengguna
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.',
                }, status=401)

            # 2. Otorisasi (hanya admin / operator internal, portal/customer dilarang mengirim WA)
            if user.has_group('base.group_portal') or not user.has_group('base.group_user'):
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Hanya admin atau operator yang berwenang mengirim notifikasi WhatsApp.',
                }, status=403)

            # 3. Parsing Payload JSON
            body = {}
            if request.httprequest.data:
                try:
                    body = json.loads(request.httprequest.data.decode('utf-8'))
                except (ValueError, UnicodeDecodeError):
                    return self._json_response({
                        'success': False,
                        'message': 'Payload request tidak valid. Format JSON diperlukan.',
                    }, status=400)

            # 3. Cari Pesanan
            order = request.env['laundry.order'].with_user(user).browse(order_id)
            if not order.exists():
                return self._json_response({
                    'success': False,
                    'message': f"Pesanan dengan ID {order_id} tidak ditemukan.",
                }, status=404)

            # 4. Validasi Parameter Template
            template = (body.get('template') or 'invoice').strip().lower()
            valid_templates = ['invoice', 'created', 'order_created', 'ready', 'order_ready', 'reminder', 'custom']
            if template not in valid_templates:
                return self._json_response({
                    'success': False,
                    'message': f"Template '{template}' tidak valid. Pilihan yang tersedia: invoice, ready, reminder, custom.",
                }, status=400)

            custom_text = body.get('custom_message') or body.get('message') or ''
            if template == 'custom' and not str(custom_text).strip():
                return self._json_response({
                    'success': False,
                    'message': "Parameter 'custom_message' wajib diisi jika template bernilai 'custom'.",
                }, status=400)

            phone = body.get('phone')
            if phone:
                from ..utils.phone_utils import normalize_phone_number, is_valid_whatsapp_number
                norm_phone = normalize_phone_number(phone)
                if not is_valid_whatsapp_number(norm_phone):
                    return self._json_response({
                        'success': False,
                        'message': f"Nomor telepon tujuan '{phone}' tidak valid untuk WhatsApp. Gunakan format yang benar (misal: 08123456789 atau 628123456789).",
                        'phone': phone,
                    }, status=400)
                phone = norm_phone

            send_immediate = body.get('send_immediate', True)

            # 5. Eksekusi Pengiriman Notifikasi WhatsApp
            result = order.action_send_whatsapp_notification(
                template_type=template,
                custom_text=custom_text,
                phone=phone,
                send_immediate=send_immediate,
            )

            if not result.get('success'):
                return self._json_response({
                    'success': False,
                    'message': result.get('message', 'Pengiriman WhatsApp gagal.'),
                    'phone': result.get('phone'),
                }, status=400)

            last_sent_str = order.whatsapp_last_sent.strftime('%Y-%m-%d %H:%M:%S') if order.whatsapp_last_sent else None

            return self._json_response({
                'success': True,
                'message': result.get('message', 'Notifikasi WhatsApp berhasil diproses.'),
                'data': {
                    'order_id': order.id,
                    'order_number': order.name,
                    'recipient_phone': result.get('phone'),
                    'template_used': result.get('template_used'),
                    'outbox_id': result.get('outbox_id'),
                    'is_delivered': result.get('is_delivered'),
                    'whatsapp_status': order.whatsapp_status,
                    'whatsapp_last_sent': last_sent_str,
                }
            }, status=200)

        except AccessError as e:
            return self._json_response({
                'success': False,
                'message': 'Akses ditolak: Anda tidak memiliki izin untuk operasi ini.',
            }, status=403)
        except (UserError, ValidationError) as e:
            return self._json_response({
                'success': False,
                'message': str(e),
            }, status=400)
        except Exception as e:
            _logger.exception("Error in send_order_whatsapp: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server saat mengirim pesan WhatsApp.',
            }, status=500)

    @http.route(
        [
            '/api/orders/<int:order_id>/whatsapp-status',
            '/api/laundry/orders/<int:order_id>/whatsapp-status',
        ],
        type='http',
        auth='public',
        methods=['GET', 'OPTIONS'],
        csrf=False,
    )
    def get_order_whatsapp_status(self, order_id, **kwargs):
        """
        Mendapatkan status pengiriman WhatsApp terakhir dan riwayat pengiriman pesan untuk pesanan terkait.
        """
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            # 1. Autentikasi Pengguna
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.',
                }, status=401)

            # 2. Cari Pesanan
            order = request.env['laundry.order'].with_user(user).browse(order_id)
            if not order.exists():
                return self._json_response({
                    'success': False,
                    'message': f"Pesanan dengan ID {order_id} tidak ditemukan.",
                }, status=404)

            # 3. Otorisasi (portal hanya boleh melihat pesanan miliknya sendiri)
            if user.has_group('base.group_portal') and order.partner_id.id != user.partner_id.id:
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Anda hanya dapat melihat status WhatsApp untuk pesanan Anda sendiri.',
                }, status=403)

            # 4. Format Riwayat Outbox
            history = []
            if hasattr(order, 'whatsapp_outbox_ids') and order.whatsapp_outbox_ids:
                # Urutkan dari yang terbaru (id descending)
                sorted_outbox = order.whatsapp_outbox_ids.sorted(key=lambda r: r.id, reverse=True)
                for item in sorted_outbox:
                    history.append({
                        'id': item.id,
                        'name': item.name or '',
                        'phone': item.phone or '',
                        'is_delivered': bool(item.is_delivered),
                        'is_queued': bool(item.is_queued),
                        'sent_date': item.sent_date.strftime('%Y-%m-%d %H:%M:%S') if item.sent_date else None,
                        'create_date': item.create_date.strftime('%Y-%m-%d %H:%M:%S') if item.create_date else None,
                        'error_msg': item.error_msg or None,
                        'message_preview': (item.message[:120] + '...') if item.message and len(item.message) > 120 else (item.message or ''),
                    })

            last_sent_str = order.whatsapp_last_sent.strftime('%Y-%m-%d %H:%M:%S') if order.whatsapp_last_sent else None

            return self._json_response({
                'success': True,
                'data': {
                    'order_id': order.id,
                    'order_number': order.name,
                    'whatsapp_status': order.whatsapp_status,
                    'whatsapp_phone': order.whatsapp_phone,
                    'whatsapp_sent': bool(order.whatsapp_sent),
                    'whatsapp_last_sent': last_sent_str,
                    'outbox_count': len(history),
                    'history': history,
                }
            }, status=200)

        except AccessError as e:
            return self._json_response({
                'success': False,
                'message': 'Akses ditolak: Anda tidak memiliki izin untuk operasi ini.',
            }, status=403)
        except (UserError, ValidationError) as e:
            return self._json_response({
                'success': False,
                'message': str(e),
            }, status=400)
        except Exception as e:
            _logger.exception("Error in get_order_whatsapp_status: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server saat mengambil status WhatsApp.',
            }, status=500)

    @http.route(
        [
            '/api/orders/<int:order_id>/whatsapp-preview',
            '/api/laundry/orders/<int:order_id>/whatsapp-preview',
        ],
        type='http',
        auth='public',
        methods=['GET', 'OPTIONS'],
        csrf=False,
    )
    def preview_order_whatsapp(self, order_id, **kwargs):
        """
        Melihat pratinjau (preview) pesan WhatsApp yang telah diformat sebelum dikirim ke pelanggan.
        Mendukung query parameter:
        - template: 'invoice' (default), 'ready', 'reminder', 'custom'
        - custom_message: pesan kustom jika template='custom'
        - phone: nomor telepon tujuan (opsional override)
        """
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            # 1. Autentikasi Pengguna
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.',
                }, status=401)

            # 2. Otorisasi (hanya admin / operator internal, portal/customer dilarang melihat pratinjau WA)
            if user.has_group('base.group_portal') or not user.has_group('base.group_user'):
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Hanya admin atau operator yang berwenang melihat pratinjau pesan WhatsApp.',
                }, status=403)

            # 2. Ambil Query / Body Parameter
            template = (kwargs.get('template') or 'invoice').strip().lower()
            custom_message = kwargs.get('custom_message') or kwargs.get('message') or ''
            phone_override = kwargs.get('phone')

            if request.httprequest.data:
                try:
                    data = json.loads(request.httprequest.data.decode('utf-8'))
                    if 'template' in data and not kwargs.get('template'):
                        template = str(data['template']).strip().lower()
                    if 'custom_message' in data and not custom_message:
                        custom_message = data['custom_message']
                    elif 'message' in data and not custom_message:
                        custom_message = data['message']
                    if 'phone' in data and not phone_override:
                        phone_override = data['phone']
                except Exception:
                    pass

            # 3. Cari Pesanan
            order = request.env['laundry.order'].with_user(user).browse(order_id)
            if not order.exists():
                return self._json_response({
                    'success': False,
                    'message': f"Pesanan dengan ID {order_id} tidak ditemukan.",
                }, status=404)

            # 4. Validasi Template
            valid_templates = ['invoice', 'created', 'order_created', 'ready', 'order_ready', 'reminder', 'custom']
            if template not in valid_templates:
                return self._json_response({
                    'success': False,
                    'message': f"Template '{template}' tidak valid. Pilihan yang tersedia: invoice, ready, reminder, custom.",
                }, status=400)

            if template == 'custom' and not str(custom_message).strip():
                return self._json_response({
                    'success': False,
                    'message': "Parameter 'custom_message' wajib diisi jika template bernilai 'custom'.",
                }, status=400)

            # 5. Resolve Target Phone
            from ..utils.phone_utils import normalize_phone_number, is_valid_whatsapp_number
            target_phone = ''
            if phone_override:
                norm_override = normalize_phone_number(phone_override)
                if not is_valid_whatsapp_number(norm_override):
                    return self._json_response({
                        'success': False,
                        'message': f"Nomor telepon override '{phone_override}' tidak valid.",
                    }, status=400)
                target_phone = norm_override
            else:
                raw_phone = order.whatsapp_phone
                if not raw_phone and order.partner_id:
                    raw_phone = getattr(order.partner_id, 'mobile', None) or getattr(order.partner_id, 'phone', None)
                target_phone = normalize_phone_number(raw_phone) if raw_phone else ''

            # 6. Render Pesan WhatsApp
            from ..utils.wa_templates import get_whatsapp_message
            rendered_text = get_whatsapp_message(
                template_type=template,
                order=order,
                custom_text=custom_message,
            )

            return self._json_response({
                'success': True,
                'data': {
                    'order_id': order.id,
                    'order_number': order.name,
                    'customer_name': order.partner_id.name if order.partner_id else '',
                    'template': template,
                    'recipient_phone': target_phone,
                    'message': rendered_text,
                    'character_count': len(rendered_text),
                }
            }, status=200)

        except AccessError as e:
            return self._json_response({
                'success': False,
                'message': 'Akses ditolak: Anda tidak memiliki izin untuk operasi ini.',
            }, status=403)
        except (UserError, ValidationError) as e:
            return self._json_response({
                'success': False,
                'message': str(e),
            }, status=400)
        except Exception as e:
            _logger.exception("Error in preview_order_whatsapp: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server saat mempratinjau pesan WhatsApp.',
            }, status=500)

    @http.route(
        [
            '/api/orders/<int:order_id>/invoice',
            '/api/laundry/orders/<int:order_id>/invoice',
            '/api/invoices/<int:order_id>',
        ],
        type='http',
        auth='public',
        methods=['GET', 'OPTIONS'],
        csrf=False,
    )
    def get_order_invoice(self, order_id, **kwargs):
        """
        Mengembalikan data faktur / nota transaksi (invoice) lengkap untuk satu pesanan tertentu.
        Menghilangkan kebutuhan mock data di Flutter InvoiceSection.
        """
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.',
                }, status=401)

            order = request.env['laundry.order'].with_user(user).browse(order_id)
            if not order.exists():
                return self._json_response({
                    'success': False,
                    'message': f"Pesanan dengan ID {order_id} tidak ditemukan.",
                }, status=404)

            # Pelanggan portal hanya boleh melihat invoice miliknya sendiri
            if user.has_group('base.group_portal') and order.partner_id.id != user.partner_id.id:
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Anda hanya dapat melihat nota pesanan milik Anda sendiri.',
                }, status=403)

            lines_data = []
            for line in order.line_ids:
                lines_data.append({
                    'id': line.id,
                    'product_id': line.product_template_id.id,
                    'product_name': line.product_template_id.name,
                    'pricing_type': line.pricing_type,
                    'uom': line.uom_id.name if line.uom_id else '',
                    'quantity': line.quantity,
                    'weight': line.weight,
                    'length': line.length,
                    'width': line.width,
                    'area': line.area,
                    'price_unit': line.price_unit,
                    'subtotal': line.subtotal,
                    'item_details': line.item_details or '',
                })

            subtotal_services = sum(line.subtotal for line in order.line_ids)
            inv_number = order.invoice_id.name if order.invoice_id else f"INV/{order.name}"

            partner_phone = getattr(order.partner_id, 'phone', None) or getattr(order.partner_id, 'mobile', None) or order.whatsapp_phone or ''
            partner_address = order.partner_id.contact_address or ''
            delivery_address = getattr(order, 'delivery_address', None) or partner_address

            return self._json_response({
                'success': True,
                'data': {
                    'invoice_number': inv_number,
                    'order_id': order.id,
                    'order_number': order.name,
                    'invoice_date': order.order_date.isoformat() if order.order_date else None,
                    'customer': {
                        'id': order.partner_id.id,
                        'name': order.partner_id.name,
                        'phone': partner_phone,
                        'address': partner_address,
                    },
                    'service_speed': order.service_speed,
                    'service_speed_fee': float(order.service_speed_fee or 0.0),
                    'delivery_type': getattr(order, 'delivery_type', 'pickup') or 'pickup',
                    'delivery_address': delivery_address,
                    'delivery_fee': float(getattr(order, 'delivery_fee', 0.0) or 0.0),
                    'subtotal_services': float(subtotal_services),
                    'total_amount': float(order.total_amount or 0.0),
                    'amount_paid': float(getattr(order, 'amount_paid', 0.0) or 0.0),
                    'amount_due': float(getattr(order, 'amount_due', 0.0) or 0.0),
                    'change_amount': float(getattr(order, 'change_amount', 0.0) or 0.0),
                    'payment_status': getattr(order, 'payment_status', 'unpaid') or 'unpaid',
                    'payment_method': getattr(order, 'payment_method', None) or None,
                    'payment_date': order.payment_date.strftime('%Y-%m-%d %H:%M:%S') if getattr(order, 'payment_date', None) else None,
                    'payment_reference': getattr(order, 'payment_reference', None) or None,
                    'state': order.state,
                    'notes': order.notes or '',
                    'lines': lines_data,
                }
            }, status=200)

        except AccessError:
            return self._json_response({
                'success': False,
                'message': 'Akses ditolak untuk pesanan ini.',
            }, status=403)
        except Exception as e:
            _logger.exception("Error in get_order_invoice: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server saat memuat invoice.',
            }, status=500)

    @http.route(
        [
            '/api/orders/<int:order_id>/payment',
            '/api/laundry/orders/<int:order_id>/payment',
            '/api/orders/<int:order_id>/pay',
        ],
        type='http',
        auth='public',
        methods=['POST', 'OPTIONS'],
        csrf=False,
    )
    def record_order_payment(self, order_id, **kwargs):
        """
        Mencatat pembayaran pesanan laundry (tunai/cash, QRIS, transfer bank).
        Otomatis menghitung status lunas/sebagian, sisa tagihan, dan uang kembalian.
        """
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            # 1. Autentikasi
            user = self._get_authenticated_user(request, session_store_fn=session_store)
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.',
                }, status=401)

            # 2. Otorisasi (Hanya staf internal / kasir yang boleh mencatat pembayaran)
            if user.has_group('base.group_portal') or not user.has_group('base.group_user'):
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Hanya kasir atau staf internal yang berwenang mencatat pembayaran.',
                }, status=403)

            # 3. Parse JSON Body
            body = {}
            if request.httprequest.data:
                try:
                    body = json.loads(request.httprequest.data.decode('utf-8'))
                except Exception:
                    return self._json_response({
                        'success': False,
                        'message': 'Format payload JSON tidak valid.',
                    }, status=400)

            # 4. Cari Pesanan
            order = request.env['laundry.order'].with_user(user).browse(order_id)
            if not order.exists():
                return self._json_response({
                    'success': False,
                    'message': f"Pesanan dengan ID {order_id} tidak ditemukan.",
                }, status=404)

            # 5. Validasi Parameter Pembayaran
            method = (body.get('payment_method') or body.get('method') or '').strip().lower()
            if not method:
                return self._json_response({
                    'success': False,
                    'message': "Parameter 'payment_method' wajib diisi (pilihan: cash, qris, transfer).",
                }, status=400)

            amount_paid_raw = body.get('amount_paid') or body.get('amount')
            amount_paid = None
            if amount_paid_raw is not None:
                try:
                    amount_paid = float(amount_paid_raw)
                except (ValueError, TypeError):
                    return self._json_response({
                        'success': False,
                        'message': "Nominal 'amount_paid' harus berupa angka yang valid.",
                    }, status=400)

            payment_reference = body.get('reference') or body.get('payment_reference')
            notes = body.get('notes')

            # 6. Eksekusi Pencatatan Pembayaran
            res = order.action_record_payment(
                payment_method=method,
                amount_paid=amount_paid,
                payment_reference=payment_reference,
                notes=notes,
            )

            # Opsional generate account.move jika belum dibuat
            try:
                order.action_generate_invoice()
            except Exception as ie:
                _logger.warning("Auto invoice generate note: %s", str(ie))

            inv_number = order.invoice_id.name if order.invoice_id else f"INV/{order.name}"

            return self._json_response({
                'success': True,
                'message': f"Pembayaran {method.upper()} sebesar Rp {res['amount_paid']:,.0f} berhasil dicatat.",
                'data': {
                    'invoice_number': inv_number,
                    'order_id': order.id,
                    'order_number': order.name,
                    'total_amount': res['total_amount'],
                    'amount_paid': res['amount_paid'],
                    'amount_due': res['amount_due'],
                    'change_amount': res['change_amount'],
                    'payment_status': res['payment_status'],
                    'payment_method': res['payment_method'],
                    'payment_date': res['payment_date'],
                    'payment_reference': res['payment_reference'],
                }
            }, status=200)

        except (ValidationError, UserError) as ve:
            return self._json_response({
                'success': False,
                'message': str(ve),
            }, status=400)
        except AccessError:
            return self._json_response({
                'success': False,
                'message': 'Akses ditolak: Anda tidak memiliki izin untuk transaksi ini.',
            }, status=403)
        except Exception as e:
            _logger.exception("Error in record_order_payment: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server saat mencatat pembayaran.',
            }, status=500)




