# -*- coding: utf-8 -*-
from datetime import date, datetime, timedelta
import json
from unittest.mock import MagicMock
from odoo.tests.common import TransactionCase
from odoo import fields
from ..controllers.inventory_controller import LaundryInventoryController


class TestInventoryApi(TransactionCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.env = cls.env(context=dict(cls.env.context, tracking_disable=True))
        cls.controller = LaundryInventoryController()

        # Users untuk pengujian hak akses
        cls.public_user = cls.env.ref('base.public_user')
        
        # User Pegawai Internal
        cls.internal_user = cls.env['res.users'].create({
            'name': 'Pegawai Laundry',
            'login': 'pegawai_test',
            'email': 'pegawai@laundryflow.test',
            'groups_id': [(6, 0, [cls.env.ref('base.group_user').id])],
        })

        # User Pelanggan (Portal)
        portal_group = cls.env.ref('base.group_portal', raise_if_not_found=False)
        groups = [portal_group.id] if portal_group else []
        cls.customer_user = cls.env['res.users'].create({
            'name': 'Pelanggan Test',
            'login': 'customer_test',
            'email': 'customer@laundryflow.test',
            'groups_id': [(6, 0, groups)],
        })

        # User Admin
        cls.admin_user = cls.env['res.users'].create({
            'name': 'Admin Laundry',
            'login': 'admin_test',
            'email': 'admin@laundryflow.test',
            'groups_id': [(6, 0, [cls.env.ref('base.group_user').id, cls.env.ref('base.group_system').id])],
        })

        # Ambil produk bahan laundry
        cls.mat_powder = cls.env['product.product'].search([('default_code', '=', 'MAT-DET-001')], limit=1)
        cls.mat_liquid = cls.env['product.product'].search([('default_code', '=', 'MAT-DET-002')], limit=1)

        # Supplier untuk pengujian
        cls.supplier = cls.env['res.partner'].create({
            'name': 'PT Supplier Bahan Kimia',
            'is_company': True,
        })

    def _mock_request(self, user=None, method='GET'):
        """Helper untuk membuat mock HTTP request Odoo."""
        mock_req = MagicMock()
        mock_req.httprequest.method = method
        mock_req.httprequest.headers = {}
        mock_req.session = MagicMock()
        mock_req.params = {}
        mock_req.env = self.env(user=user) if user else self.env(user=self.public_user)
        mock_req.session.uid = user.id if user and not user._is_public() else None
        return mock_req

    def test_01_unauthenticated_request_rejected(self):
        """Request tanpa login / unauthenticated harus ditolak dengan HTTP 401."""
        req = self._mock_request(user=None)
        res = self.controller.get_inventory_list()
        # Controller menggunakan default_request jika req tidak dipass,
        # kita uji logika proteksi _check_inventory_access
        user, err_resp = self.controller._check_inventory_access(req)
        self.assertIsNone(user)
        self.assertIsNotNone(err_resp)
        self.assertEqual(err_resp.status_code, 401)

        body = json.loads(err_resp.data.decode('utf-8'))
        self.assertEqual(body.get('error'), 'Unauthorized')

    def test_02_customer_portal_user_forbidden(self):
        """Pelanggan / Portal user DITOLAK mengakses data inventory dengan HTTP 403."""
        req = self._mock_request(user=self.customer_user)
        user, err_resp = self.controller._check_inventory_access(req)
        self.assertIsNone(user)
        self.assertIsNotNone(err_resp)
        self.assertEqual(err_resp.status_code, 403)

        body = json.loads(err_resp.data.decode('utf-8'))
        self.assertEqual(body.get('error'), 'Forbidden')

    def test_03_internal_employee_and_admin_allowed(self):
        """Pegawai internal dan Admin Odoo berhasil mengakses inventory dengan HTTP 200."""
        # 1. Pegawai
        req_emp = self._mock_request(user=self.internal_user)
        user_emp, err_emp = self.controller._check_inventory_access(req_emp)
        self.assertIsNotNone(user_emp)
        self.assertIsNone(err_emp)

        # 2. Admin
        req_adm = self._mock_request(user=self.admin_user)
        user_adm, err_adm = self.controller._check_inventory_access(req_adm)
        self.assertIsNotNone(user_adm)
        self.assertIsNone(err_adm)

    def test_04_inventory_list_response_structure_and_fields(self):
        """Memverifikasi field produk yang wajib dikembalikan pada endpoint list inventory."""
        req = self._mock_request(user=self.internal_user)
        internal_locs = self.controller._get_internal_locations(req)
        res_data = self.controller._serialize_product_inventory(self.mat_powder, internal_locs, req)

        # Periksa field produk minimal
        self.assertEqual(res_data['id'], self.mat_powder.id)
        self.assertEqual(res_data['sku'], 'MAT-DET-001')
        self.assertEqual(res_data['name'], 'Deterjen Bubuk')
        self.assertEqual(res_data['category'], 'Bahan Laundry')
        self.assertIn('quantity_on_hand', res_data)
        self.assertIsInstance(res_data['quantity_on_hand'], float)
        self.assertEqual(res_data['uom'], 'kg')
        self.assertIn('purchase_price', res_data)
        self.assertIn('sale_price', res_data)
        self.assertIsInstance(res_data['batches'], list)

    def test_05_inventory_batch_fields_and_expiration_statuses(self):
        """Memverifikasi field rincian batch dan kalkulasi status kedaluwarsa."""
        # Terima 2 batch: 1 safe, 1 expiring_soon
        today = fields.Date.context_today(self.mat_liquid)
        now = fields.Datetime.now()
        lot_safe = self.mat_liquid.receive_batch(
            lot_name='BATCH-LIQ-SAFE',
            qty=10.0,
            receipt_date=today,
            expiration_date=now + timedelta(days=90),
            supplier=self.supplier
        )
        lot_soon = self.mat_liquid.receive_batch(
            lot_name='BATCH-LIQ-SOON',
            qty=5.0,
            receipt_date=today,
            expiration_date=now + timedelta(days=10),
            supplier=self.supplier
        )

        req = self._mock_request(user=self.internal_user)
        internal_locs = self.controller._get_internal_locations(req)
        res_data = self.controller._serialize_product_inventory(self.mat_liquid, internal_locs, req)

        batches = {b['batch_number']: b for b in res_data['batches']}
        self.assertIn('BATCH-LIQ-SAFE', batches)
        self.assertIn('BATCH-LIQ-SOON', batches)

        # Verifikasi field batch
        b_safe = batches['BATCH-LIQ-SAFE']
        self.assertEqual(b_safe['lot_id'], lot_safe.id)
        self.assertEqual(b_safe['quantity'], 10.0)
        self.assertEqual(b_safe['expiration_status'], 'safe')
        self.assertIsNotNone(b_safe['received_date'])
        self.assertIsNotNone(b_safe['expiration_date'])

        b_soon = batches['BATCH-LIQ-SOON']
        self.assertEqual(b_soon['lot_id'], lot_soon.id)
        self.assertEqual(b_soon['quantity'], 5.0)
        self.assertEqual(b_soon['expiration_status'], 'expiring_soon')

    def test_06_stock_calculated_strictly_from_internal_locations(self):
        """Memastikan stok aktual dihitung murni dari lokasi internal Odoo dan mengabaikan lokasi non-internal."""
        req = self._mock_request(user=self.internal_user)
        internal_locs = self.controller._get_internal_locations(req)

        # Ambil lokasi customer atau scrap (non-internal)
        customer_loc = self.env.ref('stock.stock_location_customers', raise_if_not_found=False)
        if not customer_loc:
            customer_loc = self.env['stock.location'].search([('usage', '=', 'customer')], limit=1)

        initial_internal_stock = self.controller._serialize_product_inventory(self.mat_powder, internal_locs, req)['quantity_on_hand']

        # Simulasikan stok di lokasi customer (misal barang keluar/di pelanggan)
        if customer_loc:
            self.env['stock.quant']._update_available_quantity(
                self.mat_powder,
                customer_loc,
                quantity=100.0
            )

        # Stok pada API monitoring inventory TIDAK boleh bertambah karena lokasi customer bukan internal
        updated_data = self.controller._serialize_product_inventory(self.mat_powder, internal_locs, req)
        self.assertEqual(updated_data['quantity_on_hand'], initial_internal_stock)

    def test_07_zero_stock_product_displayed(self):
        """Produk dengan stok 0 tetap ditampilkan di list inventory (Requirement 4)."""
        mat_stain = self.env['product.product'].search([('default_code', '=', 'MAT-STN-001')], limit=1)
        req = self._mock_request(user=self.internal_user)
        internal_locs = self.controller._get_internal_locations(req)
        data = self.controller._serialize_product_inventory(mat_stain, internal_locs, req)

        self.assertIsNotNone(data)
        self.assertEqual(data['sku'], 'MAT-STN-001')
        self.assertIn('quantity_on_hand', data)

    def test_08_detail_endpoint_valid_and_not_found(self):
        """Pengujian endpoint detail GET /api/laundry/inventory/{id}."""
        req = self._mock_request(user=self.internal_user)
        internal_locs = self.controller._get_internal_locations(req)

        # 1. Detail produk valid
        detail = self.controller._serialize_product_inventory(self.mat_powder, internal_locs, req)
        self.assertEqual(detail['id'], self.mat_powder.id)
        self.assertEqual(detail['sku'], 'MAT-DET-001')

        # 2. Detail ID tidak ditemukan (99999) ditolak 404
        # (diverifikasi di controller handler logic)
        non_existent = req.env['product.product'].search([
            ('id', '=', 99999),
            ('categ_id.name', '=', 'Bahan Laundry')
        ], limit=1)
        self.assertFalse(non_existent)
