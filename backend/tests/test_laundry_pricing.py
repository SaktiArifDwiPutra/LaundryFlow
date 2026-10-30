from odoo.exceptions import ValidationError
from odoo.tests.common import TransactionCase


class TestLaundryPricing(TransactionCase):
    """
    Unit test suite for LaundryFlow Order Pricing Calculation (Tugas 5).
    Covers:
    A. Pricing based on KG: Total = berat × harga per kg
    B. Pricing based on PCS: Total = jumlah × harga per pcs
    C. Pricing based on SET: Total = jumlah set × harga per set
    D. Pricing based on M²: Luas karpet = panjang × lebar, Total = luas × harga per m²
    - Strict validation: reject zero and negative dimensions for area
    - Storage of length, width, and area on order lines
    - Configurable area rounding (or exact / awaiting business decision)
    - Backend recalculation & untrusted client totals
    - Snapshot of catalog prices & immutability of legacy transactions
    - Multiple service lines in a single order
    - Legacy order backward compatibility
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.partner = cls.env["res.partner"].create({
            "name": "Budi Pelanggan",
            "phone": "081234567890",
        })

        # Fetch or link UoMs
        cls.uom_kg = cls.env["uom.uom"].search([("name", "=", "kg")], limit=1) or cls.env["uom.uom"].browse(16)
        cls.uom_pcs = cls.env["uom.uom"].search([("name", "=", "pcs")], limit=1) or cls.env["uom.uom"].browse(31)
        cls.uom_set = cls.env["uom.uom"].search([("name", "=", "set")], limit=1) or cls.env["uom.uom"].browse(41)
        cls.uom_m2 = cls.env["uom.uom"].search([("name", "in", ["m²", "m2"])], limit=1) or cls.env["uom.uom"].browse(11)

        # Service Category
        cls.cat_service = cls.env["product.category"].search([("name", "=", "Layanan Laundry")], limit=1)
        if not cls.cat_service:
            cls.cat_service = cls.env["product.category"].create({"name": "Layanan Laundry"})

        # Service Products in Odoo
        cls.srv_kg = cls.env["product.template"].create({
            "name": "Cuci Kiloan Standar",
            "default_code": "SRV-TEST-KG",
            "type": "service",
            "list_price": 8000.0,
            "uom_id": cls.uom_kg.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })
        cls.srv_pcs = cls.env["product.template"].create({
            "name": "Cuci Selimut Tebal",
            "default_code": "SRV-TEST-PCS",
            "type": "service",
            "list_price": 25000.0,
            "uom_id": cls.uom_pcs.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })
        cls.srv_set = cls.env["product.template"].create({
            "name": "Cuci Bedcover Set",
            "default_code": "SRV-TEST-SET",
            "type": "service",
            "list_price": 40000.0,
            "uom_id": cls.uom_set.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })
        cls.srv_carpet = cls.env["product.template"].create({
            "name": "Cuci Karpet Mewah",
            "default_code": "SRV-TEST-M2",
            "type": "service",
            "list_price": 15000.0,
            "uom_id": cls.uom_m2.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })

    def _set_config_param(self, key, value):
        param_obj = self.env["ir.config_parameter"].sudo()
        if hasattr(param_obj, "set_str"):
            param_obj.set_str(key, str(value))
        elif hasattr(param_obj, "set_param"):
            param_obj.set_param(key, str(value))
        else:
            rec = param_obj.search([("key", "=", key)], limit=1)
            if rec:
                rec.value = str(value)
            else:
                param_obj.create({"key": key, "value": str(value)})

    def test_01_pricing_formula_kg(self):
        """Rumus A: Total = berat * harga per kg"""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_kg.id,
                "quantity": 3.5,  # 3.5 kg
            })],
        })
        line = order.line_ids[0]
        self.assertEqual(line.pricing_type, "weight")
        self.assertEqual(line.price_unit, 8000.0)
        self.assertEqual(line.subtotal, 3.5 * 8000.0)
        self.assertEqual(line.subtotal, 28000.0)
        self.assertEqual(order.total_amount, 28000.0)
        self.assertEqual(order.weight, 3.5)

    def test_02_pricing_formula_pcs(self):
        """Rumus B: Total = jumlah * harga per pcs"""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_pcs.id,
                "quantity": 4.0,  # 4 pcs
            })],
        })
        line = order.line_ids[0]
        self.assertEqual(line.pricing_type, "unit")
        self.assertEqual(line.price_unit, 25000.0)
        self.assertEqual(line.subtotal, 4.0 * 25000.0)
        self.assertEqual(line.subtotal, 100000.0)
        self.assertEqual(order.total_amount, 100000.0)

    def test_03_pricing_formula_set(self):
        """Rumus C: Total = jumlah set * harga per set"""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_set.id,
                "quantity": 2.0,  # 2 sets
            })],
        })
        line = order.line_ids[0]
        self.assertEqual(line.pricing_type, "set")
        self.assertEqual(line.price_unit, 40000.0)
        self.assertEqual(line.subtotal, 2.0 * 40000.0)
        self.assertEqual(line.subtotal, 80000.0)
        self.assertEqual(order.total_amount, 80000.0)

    def test_04_pricing_formula_area_carpet(self):
        """
        Rumus D:
        Luas karpet = panjang * lebar
        Total karpet = luas * harga per m²
        Contoh pengujian dari spesifikasi:
        - Panjang karpet 2 meter.
        - Lebar karpet 3 meter.
        - Luas 6 m².
        - Harga ilustrasi Rp15.000/m².
        - Total ilustrasi Rp90.000.
        """
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_carpet.id,
                "length": 2.0,
                "width": 3.0,
                "quantity": 1.0,
            })],
        })
        line = order.line_ids[0]
        self.assertEqual(line.pricing_type, "area")
        self.assertEqual(line.length, 2.0)
        self.assertEqual(line.width, 3.0)
        self.assertEqual(line.area, 6.0)
        self.assertEqual(line.price_unit, 15000.0)
        self.assertEqual(line.subtotal, 90000.0)
        self.assertEqual(order.total_amount, 90000.0)

        # Uji juga jika kuantitas karpet identik lebih dari 1 helai (misal 2 helai karpet 2x3 m)
        line.quantity = 2.0
        line._compute_subtotal()
        self.assertEqual(line.subtotal, 6.0 * 15000.0 * 2.0)
        self.assertEqual(line.subtotal, 180000.0)

    def test_05_dimension_validation_reject_zero_and_negative(self):
        """Ketentuan: Panjang dan lebar harus positif, tolak angka nol dan negatif."""
        # Tolak panjang 0
        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_carpet.id,
                    "length": 0.0,
                    "width": 3.0,
                })],
            })

        # Tolak lebar 0
        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_carpet.id,
                    "length": 2.0,
                    "width": 0.0,
                })],
            })

        # Tolak panjang negatif
        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_carpet.id,
                    "length": -2.0,
                    "width": 3.0,
                })],
            })

        # Tolak lebar negatif
        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_carpet.id,
                    "length": 2.0,
                    "width": -3.0,
                })],
            })

    def test_06_quantity_validation_reject_zero_and_negative(self):
        """Tolak jumlah dan kuantitas nol atau negatif."""
        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_kg.id,
                    "quantity": 0.0,
                })],
            })

        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_pcs.id,
                    "quantity": -1.0,
                })],
            })

    def test_07_dimensions_saved_on_order_line(self):
        """Ketentuan: Simpan panjang, lebar, dan luas pada detail order."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_carpet.id,
                "length": 2.5,
                "width": 1.5,
            })],
        })
        line = order.line_ids[0]
        self.assertEqual(line.length, 2.5)
        self.assertEqual(line.width, 1.5)
        self.assertEqual(line.area, 3.75)

    def test_08_area_rounding_configurable(self):
        """
        Ketentuan 5 & 6:
        - Aturan pembulatan luas harus dapat dikonfigurasi atau menunggu keputusan bisnis.
        - Jangan membuat aturan pembulatan sendiri.
        """
        # Default: tanpa pembulatan buatan sendiri (exact = 2.5 * 1.5 = 3.75)
        order1 = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_carpet.id,
                "length": 2.5,
                "width": 1.5,
            })],
        })
        self.assertEqual(order1.line_ids[0].area, 3.75)

        # Uji jika dikonfigurasi pembulatan ke atas (ceil) melalui ir.config_parameter
        self._set_config_param("laundry.area_rounding_method", "ceil")
        try:
            order2 = self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_carpet.id,
                    "length": 2.5,
                    "width": 1.5,
                })],
            })
            self.assertEqual(order2.line_ids[0].area, 4.0)
        finally:
            # Kembalikan ke default 'none'
            self._set_config_param("laundry.area_rounding_method", "none")

    def test_09_backend_recalculates_prices_ignores_flutter_total(self):
        """
        Ketentuan 7 & 8:
        - Backend harus menghitung ulang semua harga.
        - Jangan mempercayai total dari Flutter / klien.
        """
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "total_amount": 99999999.0,  # Nilai manipulatif dari klien luar
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_kg.id,
                "quantity": 2.0,  # 2 kg * 8000 = 16000
                "subtotal": 12345.0,  # Nilai subtotal palsu dari klien luar
            })],
        })
        # Backend menghitung ulang dan mengabaikan nilai total palsu
        self.assertEqual(order.line_ids[0].subtotal, 16000.0)
        self.assertEqual(order.total_amount, 16000.0)

    def test_10_price_snapshot_and_catalog_change_immutability(self):
        """
        Ketentuan 9 & 10:
        - Simpan snapshot harga saat transaksi dibuat.
        - Perubahan harga katalog tidak boleh mengubah transaksi lama.
        """
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_kg.id,
                "quantity": 2.0,
            })],
        })
        line = order.line_ids[0]
        self.assertEqual(line.price_unit, 8000.0)
        self.assertEqual(line.subtotal, 16000.0)
        self.assertEqual(order.total_amount, 16000.0)

        # Ubah harga di master katalog Odoo (misal naik jadi 12000 per kg)
        self.srv_kg.write({"list_price": 12000.0})

        # Panggil recompute_prices atau re-read pada order lama
        order.recompute_prices()
        order.invalidate_recordset()

        # Transaksi lama HARUS TETAP menggunakan snapshot harga awal (8000)
        self.assertEqual(order.line_ids[0].price_unit, 8000.0)
        self.assertEqual(order.line_ids[0].subtotal, 16000.0)
        self.assertEqual(order.total_amount, 16000.0)

        # Transaksi BARU yang dibuat setelah perubahan harga akan menggunakan harga katalog baru (12000)
        new_order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_kg.id,
                "quantity": 2.0,
            })],
        })
        self.assertEqual(new_order.line_ids[0].price_unit, 12000.0)
        self.assertEqual(new_order.line_ids[0].subtotal, 24000.0)
        self.assertEqual(new_order.total_amount, 24000.0)

    def test_11_multiple_service_lines_in_single_order(self):
        """Ketentuan 11: Dukung beberapa detail layanan dalam satu order."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_kg.id,
                    "quantity": 3.0,  # 3 * 8000 = 24000
                    "price_unit": 8000.0,
                }),
                (0, 0, {
                    "product_template_id": self.srv_pcs.id,
                    "quantity": 2.0,  # 2 * 25000 = 50000
                    "price_unit": 25000.0,
                }),
                (0, 0, {
                    "product_template_id": self.srv_set.id,
                    "quantity": 1.0,  # 1 * 40000 = 40000
                    "price_unit": 40000.0,
                }),
                (0, 0, {
                    "product_template_id": self.srv_carpet.id,
                    "length": 2.0,
                    "width": 3.0,
                    "quantity": 1.0,  # (2*3) * 15000 = 90000
                    "price_unit": 15000.0,
                }),
            ],
        })
        self.assertEqual(len(order.line_ids), 4)
        subtotals = order.line_ids.mapped("subtotal")
        self.assertEqual(subtotals, [24000.0, 50000.0, 40000.0, 90000.0])
        # Total = 24000 + 50000 + 40000 + 90000 = 204000
        self.assertEqual(order.total_amount, 204000.0)

    def test_12_legacy_order_backward_compatibility(self):
        """Kompatibilitas mundur dengan order lama yang tidak memiliki line_ids."""
        legacy_order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "weight": 2.0,
            "price_per_kg": 7000.0,
        })
        self.assertEqual(legacy_order.total_amount, 14000.0)
