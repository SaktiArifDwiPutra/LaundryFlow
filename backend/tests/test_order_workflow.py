# -*- coding: utf-8 -*-
from odoo import fields
from odoo.exceptions import ValidationError
from odoo.tests.common import TransactionCase


class TestLaundryOrderWorkflow(TransactionCase):
    """
    Unit test suite untuk Alur Kerja (Workflow) dan Transisi Status Pesanan Laundry (Task 1).
    Menguji:
    1. Setrika Saja: received -> ironing -> ready -> completed (tanpa washing & drying).
    2. Cuci Lipat: received -> washing -> drying -> ready -> completed (tanpa ironing).
    3. Cuci Setrika: received -> washing -> drying -> ironing -> ready -> out_for_delivery -> completed.
    4. Karpet (m²): washing -> drying -> ready (tanpa ironing).
    5. Order Campuran: gabungan multi-layanan mencakup seluruh tahapan wajib.
    6. Perbedaan aturan penyelesaian Delivery vs Pickup:
       - Delivery wajib melewati out_for_delivery sebelum completed.
       - Pickup langsung completed dari ready, dan dilarang out_for_delivery.
    7. Penolakan lompatan status (status jumping validation).
    8. Pesanan dibatalkan (cancelled): tidak dapat diproses kembali.
    9. Pesanan selesai (completed): tidak dapat dibatalkan atau diubah statusnya.
    10. Kompatibilitas pesanan lama (legacy single-service orders).
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.partner = cls.env["res.partner"].create({
            "name": "Bapak Anton Sujarwo",
            "phone": "081234567890",
        })

        cls.uom_kg = cls.env["uom.uom"].search([("name", "=", "kg")], limit=1) or cls.env["uom.uom"].browse(16)
        cls.uom_pcs = cls.env["uom.uom"].search([("name", "=", "pcs")], limit=1) or cls.env["uom.uom"].browse(31)
        cls.uom_m2 = cls.env["uom.uom"].search([("name", "in", ["m²", "m2"])], limit=1) or cls.env["uom.uom"].browse(11)

        cls.cat_service = cls.env["product.category"].search([("name", "=", "Layanan Laundry")], limit=1)
        if not cls.cat_service:
            cls.cat_service = cls.env["product.category"].create({"name": "Layanan Laundry"})

        # Produk Layanan Laundry
        cls.srv_setrika = cls.env["product.template"].create({
            "name": "Setrika Saja Kilat",
            "default_code": "SRV-TEST-IRN-01",
            "type": "service",
            "list_price": 6000.0,
            "uom_id": cls.uom_kg.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })

        cls.srv_cuci_lipat = cls.env["product.template"].create({
            "name": "Cuci Lipat Wangi",
            "default_code": "SRV-TEST-WFL-01",
            "type": "service",
            "list_price": 7000.0,
            "uom_id": cls.uom_kg.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })

        cls.srv_cuci_setrika = cls.env["product.template"].create({
            "name": "Cuci Setrika Reguler",
            "default_code": "SRV-TEST-WIR-01",
            "type": "service",
            "list_price": 10000.0,
            "uom_id": cls.uom_kg.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })

        cls.srv_karpet = cls.env["product.template"].create({
            "name": "Cuci Karpet Mewah",
            "default_code": "SRV-TEST-CRP-01",
            "type": "service",
            "list_price": 15000.0,
            "uom_id": cls.uom_m2.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })

    def test_01_setrika_saja_pickup_workflow(self):
        """Uji alur Setrika Saja (Pickup): received -> ironing -> ready -> completed."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "delivery_type": "pickup",
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_setrika.id,
                    "quantity": 3.0,
                })
            ]
        })
        self.assertEqual(order.state, "received")
        self.assertEqual(order._get_process_pipeline(), ["ironing"])

        # Setrika Saja tidak boleh dipaksa washing atau drying
        with self.assertRaises(ValidationError):
            order.action_washing()

        with self.assertRaises(ValidationError):
            order.action_drying()

        # Tidak boleh langsung ready tanpa disetrika
        with self.assertRaises(ValidationError):
            order.action_ready()

        # Proses yang benar: received -> ironing
        order.action_ironing()
        self.assertEqual(order.state, "ironing")

        # Setelah ironing -> ready
        order.action_ready()
        self.assertEqual(order.state, "ready")

        # Pesanan pickup tidak boleh out_for_delivery
        with self.assertRaises(ValidationError):
            order.action_out_for_delivery()

        # Pesanan pickup dapat diselesaikan langsung setelah ready
        order.action_complete()
        self.assertEqual(order.state, "completed")

    def test_02_setrika_saja_delivery_workflow(self):
        """Uji alur Setrika Saja (Delivery): received -> ironing -> ready -> out_for_delivery -> completed."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "delivery_type": "delivery",
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_setrika.id,
                    "quantity": 2.0,
                })
            ]
        })
        order.action_ironing()
        order.action_ready()
        self.assertEqual(order.state, "ready")

        # Delivery TIDAK boleh langsung completed dari ready
        with self.assertRaises(ValidationError):
            order.action_complete()

        # Delivery WAJIB melewati out_for_delivery
        order.action_out_for_delivery()
        self.assertEqual(order.state, "out_for_delivery")

        # Setelah out_for_delivery, dapat diselesaikan
        order.action_complete()
        self.assertEqual(order.state, "completed")

    def test_03_cuci_lipat_workflow_no_ironing(self):
        """Uji alur Cuci Lipat: received -> washing -> drying -> ready -> completed (tanpa ironing)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "delivery_type": "pickup",
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_cuci_lipat.id,
                    "quantity": 4.0,
                })
            ]
        })
        self.assertEqual(order._get_process_pipeline(), ["washing", "drying"])

        # Cuci Lipat tidak memerlukan ironing
        with self.assertRaises(ValidationError):
            order.action_ironing()

        # Tidak boleh melompati washing ke drying
        with self.assertRaises(ValidationError):
            order.action_drying()

        # Langkah 1: washing
        order.action_washing()
        self.assertEqual(order.state, "washing")

        # Cuci Lipat tetap dilarang ironing dari washing
        with self.assertRaises(ValidationError):
            order.action_ironing()

        # Langkah 2: drying
        order.action_drying()
        self.assertEqual(order.state, "drying")

        # Cuci Lipat tidak perlu ironing, langsung ke ready
        with self.assertRaises(ValidationError):
            order.action_ironing()

        order.action_ready()
        self.assertEqual(order.state, "ready")

        order.action_complete()
        self.assertEqual(order.state, "completed")

    def test_04_cuci_setrika_full_pipeline_delivery(self):
        """Uji alur Cuci Setrika (Delivery): washing -> drying -> ironing -> ready -> out_for_delivery -> completed."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "delivery_type": "delivery",
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_cuci_setrika.id,
                    "quantity": 5.0,
                })
            ]
        })
        self.assertEqual(order._get_process_pipeline(), ["washing", "drying", "ironing"])

        # Uji larangan melompati tahapan
        with self.assertRaises(ValidationError):
            order.action_drying()  # Lewati washing -> Gagal
        with self.assertRaises(ValidationError):
            order.action_ironing()  # Lewati washing & drying -> Gagal
        with self.assertRaises(ValidationError):
            order.action_ready()  # Lewati seluruh proses -> Gagal

        # Tahap 1: washing
        order.action_washing()
        self.assertEqual(order.state, "washing")

        # Tidak boleh melompati drying langsung ke ironing
        with self.assertRaises(ValidationError):
            order.action_ironing()

        # Tahap 2: drying
        order.action_drying()
        self.assertEqual(order.state, "drying")

        # Cuci Setrika WAJIB melalui ironing, tidak boleh langsung ready dari drying
        with self.assertRaises(ValidationError):
            order.action_ready()

        # Tahap 3: ironing
        order.action_ironing()
        self.assertEqual(order.state, "ironing")

        # Tahap 4: ready
        order.action_ready()
        self.assertEqual(order.state, "ready")

        # Pesanan delivery wajib out_for_delivery sebelum completed
        with self.assertRaises(ValidationError):
            order.action_complete()

        # Tahap 5: out_for_delivery
        order.action_out_for_delivery()
        self.assertEqual(order.state, "out_for_delivery")

        # Tahap 6: completed
        order.action_complete()
        self.assertEqual(order.state, "completed")

    def test_05_carpet_workflow_no_ironing(self):
        """Uji alur karpet: pencucian dan pengeringan tanpa penyetrikaan."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "delivery_type": "pickup",
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_karpet.id,
                    "length": 3.0,
                    "width": 2.0,
                    "quantity": 1.0,
                })
            ]
        })
        self.assertEqual(order._get_process_pipeline(), ["washing", "drying"])

        order.action_washing()
        order.action_drying()
        # Karpet tidak disetrika, langsung ready
        order.action_ready()
        self.assertEqual(order.state, "ready")
        order.action_complete()
        self.assertEqual(order.state, "completed")

    def test_06_mixed_order_workflow(self):
        """Uji alur pesanan campuran (Setrika Saja + Cuci Lipat): wajib melalui seluruh tahapan."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "delivery_type": "pickup",
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_setrika.id,
                    "quantity": 2.0,
                }),
                (0, 0, {
                    "product_template_id": self.srv_cuci_lipat.id,
                    "quantity": 3.0,
                }),
            ]
        })
        # Campuran mengandung item cuci dan item setrika, sehingga pipeline lengkap
        self.assertEqual(order._get_process_pipeline(), ["washing", "drying", "ironing"])

        order.action_washing()
        order.action_drying()
        order.action_ironing()
        order.action_ready()
        order.action_complete()
        self.assertEqual(order.state, "completed")

    def test_07_legacy_order_workflow_compatibility(self):
        """Uji kompatibilitas pesanan lama (legacy tanpa line_ids)."""
        # Legacy Iron Only
        legacy_iron = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "service_type": "iron",
            "weight": 2.0,
            "price_per_kg": 6000.0,
            "delivery_type": "pickup",
        })
        self.assertEqual(legacy_iron._get_process_pipeline(), ["ironing"])
        legacy_iron.action_ironing()
        legacy_iron.action_ready()
        legacy_iron.action_complete()
        self.assertEqual(legacy_iron.state, "completed")

        # Legacy Wash & Fold
        legacy_wash_fold = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "service_type": "wash_fold",
            "weight": 3.0,
            "price_per_kg": 7000.0,
            "delivery_type": "pickup",
        })
        self.assertEqual(legacy_wash_fold._get_process_pipeline(), ["washing", "drying"])
        legacy_wash_fold.action_washing()
        legacy_wash_fold.action_drying()
        legacy_wash_fold.action_ready()
        legacy_wash_fold.action_complete()
        self.assertEqual(legacy_wash_fold.state, "completed")

    def test_08_cancellation_rules_and_immutability(self):
        """Uji aturan pembatalan: dapat dibatalkan di tahap berjalan, tidak dapat diproses lagi setelah dibatalkan."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_cuci_setrika.id,
                    "quantity": 3.0,
                })
            ]
        })
        order.action_washing()
        self.assertEqual(order.state, "washing")

        # Batalkan pesanan saat sedang dicuci
        order.action_cancel()
        self.assertEqual(order.state, "cancelled")

        # Pesanan cancelled tidak boleh diproses lagi
        with self.assertRaises(ValidationError):
            order.action_washing()
        with self.assertRaises(ValidationError):
            order.action_drying()
        with self.assertRaises(ValidationError):
            order.action_ironing()
        with self.assertRaises(ValidationError):
            order.action_ready()
        with self.assertRaises(ValidationError):
            order.action_complete()

        # Tidak dapat dibatalkan dua kali
        with self.assertRaises(ValidationError):
            order.action_cancel()

    def test_09_completed_order_immutability(self):
        """Uji bahwa pesanan yang telah completed tidak dapat dibatalkan atau diubah statusnya."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "delivery_type": "pickup",
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_setrika.id,
                    "quantity": 1.0,
                })
            ]
        })
        order.action_ironing()
        order.action_ready()
        order.action_complete()
        self.assertEqual(order.state, "completed")

        # Tidak dapat dibatalkan
        with self.assertRaises(ValidationError):
            order.action_cancel()

        # Tidak dapat dipindahkan ke status lain
        with self.assertRaises(ValidationError):
            order.action_ready()
        with self.assertRaises(ValidationError):
            order.action_ironing()
        with self.assertRaises(ValidationError):
            order.write({"state": "ready"})

    def test_10_direct_write_state_jumping_blocked(self):
        """Uji bahwa direct write({'state': ...}) juga divalidasi dan menolak lompatan status."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "delivery_type": "delivery",
            "line_ids": [
                (0, 0, {
                    "product_template_id": self.srv_cuci_setrika.id,
                    "quantity": 2.0,
                })
            ]
        })
        # Mencoba bypass langsung ke completed
        with self.assertRaises(ValidationError):
            order.write({"state": "completed"})

        # Mencoba bypass langsung ke ready
        with self.assertRaises(ValidationError):
            order.write({"state": "ready"})
