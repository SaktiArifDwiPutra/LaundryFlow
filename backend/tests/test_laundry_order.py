from odoo import fields
from odoo.exceptions import ValidationError
from odoo.tests.common import TransactionCase


class TestLaundryOrderDetails(TransactionCase):
    """
    Unit test suite for LaundryFlow Order & Order Detail Models (Tugas 6).
    Covers:
    - Single detail order
    - Multi-detail order (Cuci Setrika 3 kg + Karpet 2x3 m + Selimut 1 pcs)
    - Carpet dimensions requirement (length > 0 and width > 0)
    - UoM validation and compatibility
    - Product relation constraint (must be 'service')
    - Service speed (regular, same_day) and handler (user_id) persistence
    - Item details (detail barang) storage on line and order
    - No automatic stock reduction of materials upon order creation
    - Legacy order preservation
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.partner = cls.env["res.partner"].create({
            "name": "Ibu Siti Rahma",
            "phone": "081298765432",
        })

        cls.operator = cls.env["res.users"].create({
            "name": "Operator Laundry 1",
            "login": "operator1@laundryflow.com",
            "email": "operator1@laundryflow.com",
        })

        # Fetch UoMs
        cls.uom_kg = cls.env["uom.uom"].search([("name", "=", "kg")], limit=1) or cls.env["uom.uom"].browse(16)
        cls.uom_pcs = cls.env["uom.uom"].search([("name", "=", "pcs")], limit=1) or cls.env["uom.uom"].browse(31)
        cls.uom_m2 = cls.env["uom.uom"].search([("name", "in", ["m²", "m2"])], limit=1) or cls.env["uom.uom"].browse(11)

        # Category
        cls.cat_service = cls.env["product.category"].search([("name", "=", "Layanan Laundry")], limit=1)
        if not cls.cat_service:
            cls.cat_service = cls.env["product.category"].create({"name": "Layanan Laundry"})

        cls.cat_material = cls.env["product.category"].search([("name", "=", "Bahan Laundry")], limit=1)
        if not cls.cat_material:
            cls.cat_material = cls.env["product.category"].create({"name": "Bahan Laundry"})

        # Service Products
        cls.srv_wash_iron = cls.env["product.template"].create({
            "name": "Cuci Setrika Reguler",
            "default_code": "SRV-WSH-003-T6",
            "type": "service",
            "list_price": 10000.0,
            "uom_id": cls.uom_kg.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })
        cls.srv_carpet = cls.env["product.template"].create({
            "name": "Cuci Karpet Spesial",
            "default_code": "SRV-HME-001-T6",
            "type": "service",
            "list_price": 15000.0,
            "uom_id": cls.uom_m2.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })
        cls.srv_blanket = cls.env["product.template"].create({
            "name": "Cuci Selimut Tebal",
            "default_code": "SRV-HME-002-T6",
            "type": "service",
            "list_price": 25000.0,
            "uom_id": cls.uom_pcs.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })

        # Inventory Material (Consumable)
        cls.mat_detergent = cls.env["product.template"].create({
            "name": "Deterjen Cair Premium",
            "default_code": "MAT-DET-001",
            "type": "consu",
            "is_storable": True,
            "list_price": 20000.0,
            "uom_id": cls.uom_kg.id,
            "categ_id": cls.cat_material.id,
            "purchase_ok": True,
            "sale_ok": False,
        })

    def test_01_single_detail_order(self):
        """Uji order dengan satu detail layanan."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "order_date": fields.Datetime.now(),
            "service_speed": "regular",
            "user_id": self.operator.id,
            "item_details": "4 kemeja kantor, 2 celana bahan",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_wash_iron.id,
                "quantity": 3.0,
                "item_details": "4 kemeja kantor, 2 celana bahan",
            })],
        })

        self.assertTrue(order.name.startswith("LDR/"))
        self.assertEqual(order.service_speed, "regular")
        self.assertEqual(order.user_id, self.operator)
        self.assertEqual(len(order.line_ids), 1)

        line = order.line_ids[0]
        self.assertEqual(line.product_template_id, self.srv_wash_iron)
        self.assertEqual(line.quantity, 3.0)
        self.assertEqual(line.weight, 3.0)
        self.assertEqual(line.uom_id, self.uom_kg)
        self.assertEqual(line.price_unit, 10000.0)
        self.assertEqual(line.subtotal, 30000.0)
        self.assertEqual(order.total_amount, 30000.0)
        self.assertEqual(order.weight, 3.0)

    def test_02_multi_detail_order_with_carpet_and_selimut(self):
        """
        Uji order dengan beberapa detail layanan sesuai contoh soal:
        - Cuci Setrika 3 kg (Rp10.000/kg) -> Rp30.000
        - Karpet 2 × 3 meter (Rp15.000/m²) -> 6 m² * Rp15.000 = Rp90.000
        - Selimut 1 pcs (Rp25.000/pcs) -> Rp25.000
        Total terhitung backend = Rp145.000
        """
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "service_speed": "same_day",
            "user_id": self.operator.id,
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_wash_iron.id,
                    "quantity": 3.0,
                    "item_details": "Pakaian sehari-hari",
                }),
                (0, 0, {
                    "product_template_id": self.srv_carpet.id,
                    "length": 2.0,
                    "width": 3.0,
                    "quantity": 1.0,
                    "item_details": "Karpet ruang tamu motif bunga",
                }),
                (0, 0, {
                    "product_template_id": self.srv_blanket.id,
                    "quantity": 1.0,
                    "item_details": "Selimut bulu tebal abu-abu",
                }),
            ],
        })

        self.assertEqual(len(order.line_ids), 3)
        self.assertEqual(order.service_speed, "same_day")

        line_wash = order.line_ids.filtered(lambda l: l.product_template_id == self.srv_wash_iron)
        line_carpet = order.line_ids.filtered(lambda l: l.product_template_id == self.srv_carpet)
        line_blanket = order.line_ids.filtered(lambda l: l.product_template_id == self.srv_blanket)

        # 1. Cuci Setrika
        self.assertEqual(line_wash.quantity, 3.0)
        self.assertEqual(line_wash.price_unit, 10000.0)
        self.assertEqual(line_wash.subtotal, 30000.0)

        # 2. Karpet 2x3 m
        self.assertEqual(line_carpet.length, 2.0)
        self.assertEqual(line_carpet.width, 3.0)
        self.assertEqual(line_carpet.area, 6.0)
        self.assertEqual(line_carpet.price_unit, 15000.0)
        self.assertEqual(line_carpet.subtotal, 90000.0)

        # 3. Selimut 1 pcs
        self.assertEqual(line_blanket.quantity, 1.0)
        self.assertEqual(line_blanket.price_unit, 25000.0)
        self.assertEqual(line_blanket.subtotal, 25000.0)

        # Total backend = 30000 + 90000 + 25000 = 145000
        self.assertEqual(order.total_amount, 145000.0)

    def test_03_carpet_detail_strictly_requires_dimensions(self):
        """Ketentuan 3: Detail karpet wajib memiliki ukuran panjang dan lebar positif."""
        # Tanpa ukuran (length=0, width=0)
        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_carpet.id,
                    "length": 0.0,
                    "width": 0.0,
                })],
            })

        # Panjang negatif
        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_carpet.id,
                    "length": -2.0,
                    "width": 3.0,
                })],
            })

    def test_04_uom_validation(self):
        """Ketentuan 2: Validasi UoM (satuan wajib kompatibel dengan produk)."""
        # UoM tidak kompatibel (misal menggunakan m² untuk layanan kiloan)
        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_wash_iron.id,
                    "uom_id": self.uom_m2.id,
                    "quantity": 3.0,
                })],
            })

    def test_05_product_relation_validation(self):
        """Ketentuan 1: Detail harus terhubung ke produk layanan Odoo (type='service')."""
        # Produk bahan inventaris tidak boleh dimasukkan ke detail order laundry
        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.mat_detergent.id,
                    "quantity": 1.0,
                })],
            })

    def test_06_no_automatic_stock_reduction(self):
        """
        Ketentuan 9: Jangan mengurangi stok bahan secara otomatis berdasarkan order.
        Memverifikasi bahwa pembuatan order laundry TIDAK membuat pergerakan stok (stock.move)
        atau mengubah kuantitas bahan laundry secara otomatis.
        """
        stock_move_count_before = self.env["stock.move"].search_count([
            ("product_id.product_tmpl_id", "=", self.mat_detergent.id)
        ])

        # Buat order laundry
        self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_wash_iron.id,
                "quantity": 5.0,
            })],
        })

        stock_move_count_after = self.env["stock.move"].search_count([
            ("product_id.product_tmpl_id", "=", self.mat_detergent.id)
        ])

        # Tidak ada pergerakan stok yang tercipta otomatis
        self.assertEqual(stock_move_count_before, stock_move_count_after)

    def test_07_legacy_order_integrity(self):
        """Ketentuan 7 & 8: Transaksi lama tetap ada dan integritasnya terjaga."""
        legacy_order = self.env["laundry.order"].search([("id", "=", 1)], limit=1)
        if legacy_order:
            self.assertEqual(legacy_order.name, "LDR/2026/00001")
            self.assertEqual(legacy_order.total_amount, 7000.0)
            self.assertEqual(legacy_order.weight, 1.0)

