# -*- coding: utf-8 -*-
import json
import logging
from odoo import http
from odoo.http import request as default_request
from .base import BaseApiController

_logger = logging.getLogger(__name__)


class LaundryInventoryController(BaseApiController):
    """
    Controller untuk endpoint monitoring inventory bahan laundry LaundryFlow.
    Mendukung pengecekan hak akses internal/admin, pelarangan akses pelanggan,
    penghitungan stok dari lokasi internal Odoo, serta rincian batch & kedaluwarsa.
    """

    def _check_inventory_access(self, req):
        """
        Validasi autentikasi dan hak akses:
        - Pelanggan / Portal / Publik: DITOLAK (401 jika unauth, 403 jika customer).
        - Pegawai / Internal User (base.group_user): DIIZINKAN.
        - Admin (base.group_erp_manager / base.group_system): DIIZINKAN.
        """
        user = self._get_authenticated_user(req)
        if not user:
            return None, self._json_response(
                {'error': 'Unauthorized', 'message': 'Autentikasi diperlukan untuk mengakses inventory laundry.'},
                status=401
            )

        # Cek apakah user adalah internal user / pegawai
        is_internal = user.has_group('base.group_user')
        is_portal = user.has_group('base.group_portal')

        if not is_internal or is_portal:
            return None, self._json_response(
                {'error': 'Forbidden', 'message': 'Akses ditolak. Pelanggan tidak memiliki izin untuk melihat inventory atau data internal.'},
                status=403
            )

        return user, None

    def _get_internal_locations(self, env):
        """Mengambil record lokasi internal gudang yang sah untuk perusahaan aktif."""
        company_id = env.company.id
        return env['stock.location'].search([
            ('usage', '=', 'internal'),
            ('company_id', 'in', (False, company_id))
        ])

    def _serialize_product_inventory(self, product, internal_locations, env):
        """Format data produk inventory dan seluruh batch-nya."""
        # Hitung stok aktual murni dari lokasi internal
        quants = env['stock.quant'].search([
            ('product_id', '=', product.id),
            ('location_id', 'in', internal_locations.ids)
        ])
        quantity_on_hand = sum(quants.mapped('quantity'))

        # Ambil seluruh batch/lot produk
        lots = env['stock.lot'].search([
            ('product_id', '=', product.id)
        ], order='expiration_date asc, id asc')

        batches_data = []
        for lot in lots:
            lot_quants = quants.filtered(lambda q: q.lot_id.id == lot.id)
            lot_qty = sum(lot_quants.mapped('quantity'))

            # Pastikan status kedaluwarsa ter-compute
            lot._compute_expiration_info()

            batches_data.append({
                'lot_id': lot.id,
                'batch_number': lot.name,
                'received_date': lot.receipt_date.isoformat() if lot.receipt_date else (lot.create_date.date().isoformat() if lot.create_date else None),
                'expiration_date': lot.expiration_date.isoformat() if lot.expiration_date else None,
                'quantity': float(lot_qty),
                'expiration_status': lot.expiration_status or 'unknown',
            })

        return {
            'id': product.id,
            'sku': product.default_code or '',
            'name': product.name or '',
            'category': product.categ_id.name if product.categ_id else '',
            'quantity_on_hand': float(quantity_on_hand),
            'uom': product.uom_id.name if product.uom_id else '',
            'purchase_price': float(product.standard_price or 0.0),
            'sale_price': float(product.list_price or 0.0),
            'batches': batches_data,
        }

    @http.route(
        ['/api/laundry/inventory', '/api/inventory'],
        type='http',
        auth='public',
        methods=['GET', 'OPTIONS'],
        csrf=False,
        cors='*'
    )
    def get_inventory_list(self, **kwargs):
        """
        GET /api/laundry/inventory
        Mengembalikan daftar inventory bahan laundry untuk admin dan pegawai.
        """
        req = default_request
        if req.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'}, status=200)

        try:
            user, error_response = self._check_inventory_access(req)
            if error_response:
                return error_response

            env = req.env(user=user)
            internal_locations = self._get_internal_locations(env)

            # Filter produk bahan laundry (Kategori: Bahan Laundry)
            products = env['product.product'].search([
                '|',
                ('categ_id.name', '=', 'Bahan Laundry'),
                ('categ_id.parent_id.name', '=', 'Bahan Laundry')
            ], order='default_code asc, id asc')

            if not products:
                return self._json_response({'data': []}, status=200)

            data = [
                self._serialize_product_inventory(p, internal_locations, env)
                for p in products
            ]
            return self._json_response({'data': data}, status=200)
        except Exception as e:
            _logger.exception("Error in get_inventory_list: %s", str(e))
            return self._json_response(
                {'error': 'Internal Server Error', 'message': str(e)},
                status=500
            )

    @http.route(
        ['/api/laundry/inventory/<int:product_id>', '/api/inventory/<int:product_id>'],
        type='http',
        auth='public',
        methods=['GET', 'OPTIONS'],
        csrf=False,
        cors='*'
    )
    def get_inventory_detail(self, product_id, **kwargs):
        """
        GET /api/laundry/inventory/{id}
        Mengembalikan detail produk bahan laundry tertentu beserta rincian batch.
        """
        req = default_request
        if req.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'}, status=200)

        try:
            user, error_response = self._check_inventory_access(req)
            if error_response:
                return error_response

            env = req.env(user=user)
            internal_locations = self._get_internal_locations(env)

            product = env['product.product'].search([
                '|',
                ('id', '=', product_id),
                ('product_tmpl_id', '=', product_id),
                '|',
                ('categ_id.name', '=', 'Bahan Laundry'),
                ('categ_id.parent_id.name', '=', 'Bahan Laundry')
            ], limit=1)

            if not product:
                return self._json_response(
                    {'error': 'Not Found', 'message': f'Bahan laundry dengan ID {product_id} tidak ditemukan.'},
                    status=404
                )

            data = self._serialize_product_inventory(product, internal_locations, env)
            return self._json_response({'data': data}, status=200)
        except Exception as e:
            _logger.exception("Error in get_inventory_detail: %s", str(e))
            return self._json_response(
                {'error': 'Internal Server Error', 'message': str(e)},
                status=500
            )
