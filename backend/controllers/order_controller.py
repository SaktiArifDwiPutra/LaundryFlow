import json
import logging
from odoo import http
from odoo.http import request
from odoo.http.session import session_store
from odoo.exceptions import ValidationError, AccessError
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
                data.append({
                    'id': order.id,
                    'name': order.name,
                    'order_date': order.order_date.isoformat() if order.order_date else None,
                    'partner_id': order.partner_id.id,
                    'partner_name': order.partner_id.name,
                    'service_speed': order.service_speed,
                    'service_speed_fee': float(order.service_speed_fee or 0.0),
                    'weight': float(order.weight or 0.0),
                    'total_amount': float(order.total_amount or 0.0),
                    'state': order.state,
                    'notes': order.notes or '',
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
        Membuat transaksi pesanan laundry dengan validasi jenis pengerjaan (Reguler atau Same Day Service).
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
                body = json.loads(request.httprequest.data.decode('utf-8')) if request.httprequest.data else {}
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

            speed = body.get('service_speed') or body.get('priority') or 'regular'
            # Kompatibilitas jika klien mengirim express
            if speed == 'express':
                speed = 'same_day'

            lines_data = body.get('lines') or body.get('line_ids') or []
            if not lines_data:
                return self._json_response({
                    'success': False,
                    'message': 'Detail layanan (lines) wajib diisi minimal satu baris.',
                }, status=400)

            order_lines = []
            for line in lines_data:
                prod_id = line.get('product_template_id') or line.get('product_id')
                qty = line.get('quantity') or line.get('qty') or 1.0
                order_lines.append((0, 0, {
                    'product_template_id': prod_id,
                    'quantity': qty,
                    'length': line.get('length', 0.0),
                    'width': line.get('width', 0.0),
                    'item_details': line.get('item_details', ''),
                }))

            vals = {
                'partner_id': int(partner_id),
                'service_speed': speed,
                'notes': body.get('notes', ''),
                'item_details': body.get('item_details', ''),
                'user_id': user.id,
                'line_ids': order_lines,
            }

            try:
                order = request.env['laundry.order'].with_user(user).create(vals)
            except ValidationError as ve:
                return self._json_response({
                    'success': False,
                    'message': str(ve),
                }, status=400)

            return self._json_response({
                'success': True,
                'message': 'Pesanan berhasil dibuat.',
                'data': {
                    'id': order.id,
                    'name': order.name,
                    'partner_id': order.partner_id.id,
                    'service_speed': order.service_speed,
                    'service_speed_fee': order.service_speed_fee,
                    'total_amount': order.total_amount,
                    'weight': order.weight,
                    'state': order.state,
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

            return self._json_response({
                'success': True,
                'data': {
                    'id': order.id,
                    'name': order.name,
                    'order_date': order.order_date.isoformat() if order.order_date else None,
                    'partner_id': order.partner_id.id,
                    'partner_name': order.partner_id.name,
                    'service_speed': order.service_speed,
                    'service_speed_fee': order.service_speed_fee,
                    'weight': order.weight,
                    'total_amount': order.total_amount,
                    'state': order.state,
                    'notes': order.notes or '',
                    'lines': lines_data,
                }
            }, status=200)

        except Exception as e:
            _logger.exception("Error in get_order_detail: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan pada server.',
            }, status=500)

