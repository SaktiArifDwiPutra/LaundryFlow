# -*- coding: utf-8 -*-
from datetime import date, datetime, timedelta
from odoo.tests.common import TransactionCase
from odoo.exceptions import ValidationError
from odoo import fields


class TestMaterialInventory(TransactionCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.env = cls.env(context=dict(cls.env.context, tracking_disable=True))

        cls.MaterialCategory = cls.env['product.category'].search([('name', '=', 'Bahan Laundry')], limit=1)
        if not cls.MaterialCategory:
            goods_cat = cls.env.ref('product.product_category_goods', raise_if_not_found=False)
            cls.MaterialCategory = cls.env['product.category'].create({
                'name': 'Bahan Laundry',
                'parent_id': goods_cat.id if goods_cat else False
            })

        cls.SupplierA = cls.env['res.partner'].create({
            'name': 'PT Kimia Laundry Bersih',
            'is_company': True,
        })
        cls.SupplierB = cls.env['res.partner'].create({
            'name': 'CV Parfum Harum Semerbak',
            'is_company': True,
        })

        # Ambil kelima bahan laundry
        cls.mat_powder = cls.env['product.product'].search([('default_code', '=', 'MAT-DET-001')], limit=1)
        cls.mat_liquid = cls.env['product.product'].search([('default_code', '=', 'MAT-DET-002')], limit=1)
        cls.mat_softener = cls.env['product.product'].search([('default_code', '=', 'MAT-SFT-001')], limit=1)
        cls.mat_perfume = cls.env['product.product'].search([('default_code', '=', 'MAT-PRF-001')], limit=1)
        cls.mat_stain = cls.env['product.product'].search([('default_code', '=', 'MAT-STN-001')], limit=1)

        # Pastikan kelima bahan memiliki konfigurasi lot dan expiry aktif
        materials = [cls.mat_powder, cls.mat_liquid, cls.mat_softener, cls.mat_perfume, cls.mat_stain]
        for mat in materials:
            if mat:
                mat.write({
                    'tracking': 'lot',
                    'use_expiration_date': True,
                    'is_storable': True,
                })

    def test_01_five_materials_exist_with_proper_attributes(self):
        """Memastikan kelima bahan laundry tersedia dengan SKU, nama, kategori, UoM, dan tracking yang tepat."""
        materials_map = {
            'MAT-DET-001': ('Deterjen Bubuk', 'kg'),
            'MAT-DET-002': ('Deterjen Cair', 'L'),
            'MAT-SFT-001': ('Pelembut dan Pewangi', 'L'),
            'MAT-PRF-001': ('Pelicin dan Parfum Setrika', 'L'),
            'MAT-STN-001': ('Pembersih Noda Khusus', 'L'),
        }

        for sku, (expected_name, expected_uom_name) in materials_map.items():
            product = self.env['product.product'].search([('default_code', '=', sku)], limit=1)
            self.assertTrue(product, f"Produk dengan SKU {sku} harus tersedia di Odoo.")
            self.assertEqual(product.name, expected_name)
            self.assertEqual(product.categ_id.name, 'Bahan Laundry')
            self.assertEqual(product.tracking, 'lot', f"Produk {sku} harus menggunakan tracking lot.")
            self.assertTrue(product.use_expiration_date, f"Produk {sku} harus mengaktifkan use_expiration_date.")
            self.assertEqual(product.uom_id.name, expected_uom_name)

    def test_02_batch_receipt_via_orm_success(self):
        """Penerimaan batch barang menggunakan mekanisme ORM standar Odoo (stock.quant) dan lot tracking."""
        initial_stock = self.mat_powder.qty_available
        today = fields.Date.context_today(self.mat_powder)
        exp_date = fields.Datetime.now() + timedelta(days=180)

        # Terima batch 25 kg
        lot = self.env['stock.lot'].receive_batch(
            product=self.mat_powder,
            lot_name='BATCH-POWDER-001',
            qty=25.0,
            receipt_date=today,
            expiration_date=exp_date,
            supplier=self.SupplierA
        )

        self.assertTrue(lot.id)
        self.assertEqual(lot.name, 'BATCH-POWDER-001')
        self.assertEqual(lot.supplier_id.id, self.SupplierA.id)
        self.assertEqual(lot.receipt_date, today)
        self.assertEqual(lot.product_qty, 25.0)

        # Verifikasi stok aktual produk ter-update di Odoo ORM
        self.assertEqual(self.mat_powder.qty_available, initial_stock + 25.0)

    def test_03_zero_or_negative_receipt_qty_rejected(self):
        """Validasi bahwa kuantitas penerimaan nol atau negatif ditolak oleh ORM."""
        with self.assertRaises(ValidationError):
            self.env['stock.lot'].receive_batch(
                product=self.mat_liquid,
                lot_name='BATCH-LIQ-ERR',
                qty=0.0
            )

        with self.assertRaises(ValidationError):
            self.env['stock.lot'].receive_batch(
                product=self.mat_liquid,
                lot_name='BATCH-LIQ-ERR',
                qty=-10.0
            )

        with self.assertRaises(ValidationError):
            self.env['stock.lot'].receive_batch(
                product=self.mat_liquid,
                lot_name='',
                qty=10.0
            )

    def test_04_multiple_batches_with_different_expiration_dates(self):
        """
        Satu produk dapat memiliki banyak batch dengan tanggal kedaluwarsa berbeda.
        Memastikan tanggal kedaluwarsa dicatat per batch dan tidak saling menimpa.
        """
        today = fields.Date.context_today(self.mat_liquid)
        initial_stock = self.mat_liquid.qty_available

        exp_1 = fields.Datetime.now() + timedelta(days=90)
        exp_2 = fields.Datetime.now() + timedelta(days=180)
        exp_3 = fields.Datetime.now() + timedelta(days=365)

        lot1 = self.mat_liquid.receive_batch('BATCH-LIQ-01', 10.0, receipt_date=today, expiration_date=exp_1, supplier=self.SupplierA)
        lot2 = self.mat_liquid.receive_batch('BATCH-LIQ-02', 15.0, receipt_date=today, expiration_date=exp_2, supplier=self.SupplierB)
        lot3 = self.mat_liquid.receive_batch('BATCH-LIQ-03', 20.0, receipt_date=today, expiration_date=exp_3, supplier=self.SupplierA)

        self.assertEqual(lot1.product_qty, 10.0)
        self.assertEqual(lot2.product_qty, 15.0)
        self.assertEqual(lot3.product_qty, 20.0)

        # Masing-masing batch memiliki tanggal kedaluwarsa independen
        self.assertNotEqual(lot1.expiration_date, lot2.expiration_date)
        self.assertNotEqual(lot2.expiration_date, lot3.expiration_date)

        # Total stok produk sama dengan akumulasi batch
        self.assertEqual(self.mat_liquid.qty_available, initial_stock + 45.0)

        # Verifikasi get_batches_info()
        batches = self.mat_liquid.get_batches_info()
        lot_names = [b['batch_number'] for b in batches]
        self.assertIn('BATCH-LIQ-01', lot_names)
        self.assertIn('BATCH-LIQ-02', lot_names)
        self.assertIn('BATCH-LIQ-03', lot_names)

    def test_05_batch_without_expiration_date(self):
        """Produk tanpa tanggal kedaluwarsa dapat ditangani tanpa error (status: unknown)."""
        today = fields.Date.context_today(self.mat_perfume)
        lot = self.mat_perfume.receive_batch(
            lot_name='BATCH-PRF-NOEXP',
            qty=5.0,
            receipt_date=today,
            expiration_date=False,
            supplier=self.SupplierB
        )

        self.assertFalse(lot.expiration_date)
        self.assertFalse(lot.is_expired)
        self.assertEqual(lot.expiration_status, 'unknown')
        self.assertEqual(lot.product_qty, 5.0)

    def test_06_expiration_status_and_configurable_threshold(self):
        """Verifikasi status safe, expiring_soon, expired dan ambang batas dinamis dari konfigurasi Odoo."""
        now = fields.Datetime.now()

        # Batch 1: Expired (lampau 5 hari)
        lot_expired = self.env['stock.lot'].create({
            'name': 'BATCH-EXP-01',
            'product_id': self.mat_softener.id,
            'company_id': self.env.company.id,
            'expiration_date': now - timedelta(days=5),
        })
        self.assertTrue(lot_expired.is_expired)
        self.assertEqual(lot_expired.expiration_status, 'expired')

        # Batch 2: Expiring Soon (15 hari ke depan, threshold default: 30)
        lot_soon = self.env['stock.lot'].create({
            'name': 'BATCH-EXP-02',
            'product_id': self.mat_softener.id,
            'company_id': self.env.company.id,
            'expiration_date': now + timedelta(days=15),
        })
        self.assertFalse(lot_soon.is_expired)
        self.assertEqual(lot_soon.expiration_status, 'expiring_soon')

        # Batch 3: Safe (60 hari ke depan)
        lot_safe = self.env['stock.lot'].create({
            'name': 'BATCH-EXP-03',
            'product_id': self.mat_softener.id,
            'company_id': self.env.company.id,
            'expiration_date': now + timedelta(days=60),
        })
        self.assertEqual(lot_safe.expiration_status, 'safe')

        # Ubah konfigurasi ambang batas hari menjadi 90 hari
        self.env['ir.config_parameter'].sudo().set_param('laundry.expiring_soon_days', '90')
        # Lot 3 (60 hari) sekarang harus menjadi expiring_soon karena 60 <= 90
        lot_safe._compute_expiration_info()
        self.assertEqual(lot_safe.expiration_status, 'expiring_soon')

        # Kembalikan konfigurasi default
        self.env['ir.config_parameter'].sudo().set_param('laundry.expiring_soon_days', '30')

    def test_07_minimum_stock_and_low_stock_warning(self):
        """Verifikasi batas minimum stok menggunakan stock.warehouse.orderpoint dan indikator stok rendah."""
        mat = self.mat_stain
        # Atur batas minimum stok = 50 liter
        mat.set_min_stock(min_qty=50.0, max_qty=100.0)
        self.assertEqual(mat.min_stock_qty, 50.0)

        # Saat stok di bawah atau sama dengan 50, is_low_stock harus True
        mat._compute_material_inventory_status()
        self.assertTrue(mat.is_low_stock)

        # Terima barang 60 liter sehingga total stok > 50 liter
        mat.receive_batch('BATCH-STN-FILL', 60.0, supplier=self.SupplierA)
        mat._compute_material_inventory_status()
        self.assertFalse(mat.is_low_stock)

    def test_08_order_creation_never_deducts_material_inventory(self):
        """Memastikan pembuatan pesanan laundry customer TIDAK mengurangi stok bahan inventory secara otomatis."""
        powder_stock_before = self.mat_powder.qty_available
        liquid_stock_before = self.mat_liquid.qty_available

        # Ambil produk layanan
        srv_wash = self.env['product.template'].search([('default_code', '=', 'SRV-WSH-003')], limit=1)
        customer = self.env['res.partner'].search([('name', '=', 'Customer')], limit=1)
        if not customer:
            customer = self.env['res.partner'].create({'name': 'Test Pelanggan'})

        # Buat pesanan laundry
        order = self.env['laundry.order'].create({
            'partner_id': customer.id,
            'service_speed': 'regular',
            'line_ids': [(0, 0, {
                'product_template_id': srv_wash.id,
                'weight': 5.0,
            })],
        })
        self.assertTrue(order.id)

        # Stok bahan harus tetap sama persis
        self.assertEqual(self.mat_powder.qty_available, powder_stock_before)
        self.assertEqual(self.mat_liquid.qty_available, liquid_stock_before)

    def test_09_cost_price_and_sales_price_separation(self):
        """Memastikan harga beli (standard_price) dan harga jual (list_price) independen dan menggunakan field standar Odoo."""
        mat = self.mat_powder
        mat.write({
            'standard_price': 15000.0,  # Harga beli / Cost
            'list_price': 22000.0,      # Harga jual jika dijual retail
        })

        self.assertEqual(mat.standard_price, 15000.0)
        self.assertEqual(mat.list_price, 22000.0)
        self.assertNotEqual(mat.standard_price, mat.list_price)
