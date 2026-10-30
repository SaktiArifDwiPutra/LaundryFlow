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
        methods=['POST', 'OPTIONS'],
        csrf=False,
    )
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
