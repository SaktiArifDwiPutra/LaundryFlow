# -*- coding: utf-8 -*-
import json
from unittest.mock import MagicMock, patch
from odoo.exceptions import ValidationError
from odoo.tests.common import TransactionCase
from ..controllers.order_controller import OrderApiController


class TestLaundryOrderBusinessLogic(TransactionCase):
    """
    Automated test suite untuk Validasi Order API dan Business Logic (Tugas 13).
    Memverifikasi:
    1. Order satu layanan (kg, pcs, set, m²).
    2. Order beberapa layanan sekaligus (multi-detail).
    3. Perhitungan kg (berat * harga/kg).
    4. Perhitungan pcs (jumlah * harga/pcs).
    5. Perhitungan set (jumlah * harga/set).
    6. Perhitungan karpet m² (luas = panjang * lebar, total = luas * harga/m²).
    7. Penyimpanan panjang dan lebar karpet pada order line.
    8. Snapshot harga satuan saat transaksi dibuat.
    9. Pilihan Reguler (surcharge = 0).
    10. Pilihan Same Day Service (surcharge dari konfigurasi Odoo).
    11. Validasi ketersediaan Same Day (menolak jika tidak tersedia).
    12. Perhitungan total di backend (backend recalculation).
    13. Validasi kuantitas tidak boleh negatif atau nol.
    14. Validasi panjang dan lebar karpet harus positif.
    15. Validasi UoM harus sesuai produk layanan (tolak uom yang salah).
    16. Proteksi manipulasi harga dari client (client price ignored).
    17. Immutabilitas transaksi lama saat katalog harga diperbarui.
    18. Endpoint detail pesanan (GET /api/laundry/orders/<id>) dan list (GET /api/laundry/orders).
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.controller = OrderApiController()
        cls.admin_user = cls.env.ref("base.user_admin")
        cls.public_user = cls.env.ref("base.public_user")

        cls.partner = cls.env["res.partner"].create({
            "name": "Pelanggan Pengujian Order",
            "phone": "081234567800",
            "email": "customer.order@test.com",
        })

        # Satuan / UoM
        cls.uom_kg = cls.env["uom.uom"].search([("name", "=", "kg")], limit=1) or cls.env["uom.uom"].browse(16)
        cls.uom_pcs = cls.env["uom.uom"].search([("name", "=", "pcs")], limit=1) or cls.env["uom.uom"].browse(31)
        cls.uom_set = cls.env["uom.uom"].search([("name", "=", "set")], limit=1) or cls.env["uom.uom"].browse(41)
        cls.uom_m2 = cls.env["uom.uom"].search([("name", "in", ["m²", "m2"])], limit=1) or cls.env["uom.uom"].browse(11)
        cls.uom_liter = cls.env["uom.uom"].search([("name", "in", ["L", "Liter"])], limit=1) or cls.env["uom.uom"].browse(13)

        cls.cat_service = cls.env["product.category"].search([("name", "=", "Layanan Laundry")], limit=1)
        if not cls.cat_service:
            cls.cat_service = cls.env["product.category"].create({"name": "Layanan Laundry"})

        # 1. Layanan Berdasarkan KG (Cuci Kiloan: Rp 8.000 / kg)
        cls.srv_kg = cls.env["product.template"].create({
            "name": "Cuci Kiloan Uji",
            "default_code": "SRV-TEST-KG-13",
            "type": "service",
            "list_price": 8000.0,
            "uom_id": cls.uom_kg.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
            "active": True,
        })

        # 2. Layanan Berdasarkan PCS (Selimut: Rp 25.000 / pcs)
        cls.srv_pcs = cls.env["product.template"].create({
            "name": "Cuci Selimut Uji",
            "default_code": "SRV-TEST-PCS-13",
            "type": "service",
            "list_price": 25000.0,
            "uom_id": cls.uom_pcs.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
            "active": True,
        })

        # 3. Layanan Berdasarkan SET (Sprei Set: Rp 15.000 / set)
        cls.srv_set = cls.env["product.template"].create({
            "name": "Cuci Sprei Set Uji",
            "default_code": "SRV-TEST-SET-13",
            "type": "service",
            "list_price": 15000.0,
            "uom_id": cls.uom_set.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
            "active": True,
        })

        # 4. Layanan Berdasarkan M² (Karpet: Rp 15.000 / m²)
        cls.srv_carpet = cls.env["product.template"].create({
            "name": "Cuci Karpet Uji",
            "default_code": "SRV-TEST-M2-13",
            "type": "service",
            "list_price": 15000.0,
            "uom_id": cls.uom_m2.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
            "active": True,
        })

    def _mock_request(self, user=None, method="POST", data=None, params=None):
        mock_req = MagicMock()
        mock_req.env = self.env(user=user) if user else self.env(user=self.public_user)
        mock_req.session = MagicMock()
        mock_req.session.uid = user.id if user else None
        mock_req.session.sid = "test_session_id"
        mock_req.httprequest = MagicMock()
        mock_req.httprequest.headers = {}
        mock_req.httprequest.method = method
        mock_req.params = params or {}
        if data is not None:
            mock_req.httprequest.data = json.dumps(data).encode("utf-8")
        else:
            mock_req.httprequest.data = b""
        return mock_req

    def test_01_single_service_kg_calculation(self):
        """Uji perhitungan layanan per kg: Total = berat * harga/kg."""
        payload = {
            "partner_id": self.partner.id,
            "service_speed": "regular",
            "lines": [
                {
                    "product_id": self.srv_kg.id,
                    "quantity": 3.5,  # 3.5 kg * 8000 = 28000
                }
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 201)
            body = json.loads(res.get_data(as_text=True))
            self.assertTrue(body["success"])
            data = body["data"]
            self.assertEqual(data["weight"], 3.5)
            self.assertEqual(data["total_amount"], 28000.0)
            self.assertEqual(data["service_speed_fee"], 0.0)
            self.assertEqual(data["service_speed"], "regular")

    def test_02_single_service_pcs_calculation(self):
        """Uji perhitungan layanan per pcs: Total = jumlah * harga/pcs."""
        payload = {
            "partner_id": self.partner.id,
            "service_speed": "regular",
            "lines": [
                {
                    "product_id": self.srv_pcs.id,
                    "quantity": 2.0,  # 2 pcs * 25000 = 50000
                }
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 201)
            body = json.loads(res.get_data(as_text=True))
            self.assertTrue(body["success"])
            data = body["data"]
            self.assertEqual(data["total_amount"], 50000.0)

    def test_03_single_service_set_calculation(self):
        """Uji perhitungan layanan per set: Total = jumlah set * harga/set."""
        payload = {
            "partner_id": self.partner.id,
            "service_speed": "regular",
            "lines": [
                {
                    "product_id": self.srv_set.id,
                    "quantity": 3.0,  # 3 set * 15000 = 45000
                }
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 201)
            body = json.loads(res.get_data(as_text=True))
            self.assertTrue(body["success"])
            self.assertEqual(body["data"]["total_amount"], 45000.0)

    def test_04_carpet_m2_calculation_and_dimension_storage(self):
        """
        Uji perhitungan karpet m²: Luas = panjang * lebar, Total = luas * harga/m².
        Memverifikasi bahwa panjang, lebar, dan luas tersimpan pada order line.
        """
        payload = {
            "partner_id": self.partner.id,
            "service_speed": "regular",
            "lines": [
                {
                    "product_id": self.srv_carpet.id,
                    "length": 2.0,
                    "width": 3.0,  # luas = 6.0 m2 * 15000 = 90000
                    "quantity": 1.0,
                }
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 201)
            body = json.loads(res.get_data(as_text=True))
            data = body["data"]
            self.assertEqual(data["total_amount"], 90000.0)
            self.assertEqual(len(data["lines"]), 1)
            line = data["lines"][0]
            self.assertEqual(line["length"], 2.0)
            self.assertEqual(line["width"], 3.0)
            self.assertEqual(line["area"], 6.0)
            self.assertEqual(line["price_unit"], 15000.0)
            self.assertEqual(line["subtotal"], 90000.0)

    def test_05_multi_service_order_all_types(self):
        """
        Uji pembuatan order dengan beberapa layanan sekaligus (multi-detail):
        kg + pcs + set + karpet m².
        """
        payload = {
            "partner_id": self.partner.id,
            "service_speed": "regular",
            "lines": [
                {"product_id": self.srv_kg.id, "quantity": 2.0},  # 2 * 8000 = 16000
                {"product_id": self.srv_pcs.id, "quantity": 1.0},  # 1 * 25000 = 25000
                {"product_id": self.srv_set.id, "quantity": 2.0},  # 2 * 15000 = 30000
                {"product_id": self.srv_carpet.id, "length": 2.0, "width": 1.5, "quantity": 1.0},  # 3 m2 * 15000 = 45000
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 201)
            body = json.loads(res.get_data(as_text=True))
            data = body["data"]
            # Total = 16000 + 25000 + 30000 + 45000 = 116000
            self.assertEqual(data["total_amount"], 116000.0)
            self.assertEqual(len(data["lines"]), 4)

    def test_06_same_day_service_with_configured_surcharge(self):
        """Uji Same Day Service dengan biaya surcharge dari konfigurasi Odoo."""
        self.env["laundry.order"].set_same_day_config(available=True, surcharge=15000.0)
        payload = {
            "partner_id": self.partner.id,
            "service_speed": "same_day",
            "lines": [
                {"product_id": self.srv_kg.id, "quantity": 2.0},  # 2 * 8000 = 16000
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 201)
            body = json.loads(res.get_data(as_text=True))
            data = body["data"]
            self.assertEqual(data["service_speed"], "same_day")
            self.assertEqual(data["service_speed_fee"], 15000.0)
            # Total = 16000 + 15000 = 31000
            self.assertEqual(data["total_amount"], 31000.0)

    def test_07_same_day_service_rejected_when_unavailable(self):
        """Backend menolak order Same Day Service jika sedang dinonaktifkan admin."""
        self.env["laundry.order"].set_same_day_config(available=False, surcharge=15000.0)
        payload = {
            "partner_id": self.partner.id,
            "service_speed": "same_day",
            "lines": [
                {"product_id": self.srv_kg.id, "quantity": 2.0},
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 400)
            body = json.loads(res.get_data(as_text=True))
            self.assertFalse(body["success"])
            self.assertIn("tidak tersedia", body["message"])

    def test_08_price_manipulation_protection(self):
        """
        Validasi integritas harga:
        Backend mengabaikan nilai price, price_unit, subtotal, dan total_amount dari client.
        Harga dihitung ulang murni dari katalog Odoo.
        """
        payload = {
            "partner_id": self.partner.id,
            "service_speed": "regular",
            "total_amount": 500,  # Dicoba manipulasi
            "lines": [
                {
                    "product_id": self.srv_kg.id,
                    "quantity": 2.0,
                    "price": 100,  # Dicoba manipulasi
                    "price_unit": 100,  # Dicoba manipulasi
                    "subtotal": 200,  # Dicoba manipulasi
                }
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 201)
            body = json.loads(res.get_data(as_text=True))
            data = body["data"]
            # Backend harus tetap menghitung 2 kg * 8000 = 16000
            self.assertEqual(data["total_amount"], 16000.0)
            self.assertEqual(data["lines"][0]["price_unit"], 8000.0)
            self.assertEqual(data["lines"][0]["subtotal"], 16000.0)

    def test_09_historical_order_price_immutability(self):
        """
        Validasi snapshot harga:
        Ketika katalog harga Odoo diubah di masa depan, transaksi lama tidak boleh berubah nilainya.
        """
        payload = {
            "partner_id": self.partner.id,
            "service_speed": "regular",
            "lines": [
                {"product_id": self.srv_kg.id, "quantity": 2.0},  # 2 * 8000 = 16000
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 201)
            order_id = json.loads(res.get_data(as_text=True))["data"]["id"]

        # Admin menaikkan harga katalog dari Rp 8.000 menjadi Rp 12.000
        self.srv_kg.write({"list_price": 12000.0})

        # Cek detail order lama melalui API: nilainya harus tetap Rp 16.000 (snapshot 8.000)
        mock_detail = self._mock_request(user=self.admin_user, method="GET")
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_detail):
            res_detail = self.controller.get_order_detail(order_id)
            self.assertEqual(res_detail.status_code, 200)
            body_detail = json.loads(res_detail.get_data(as_text=True))
            data_detail = body_detail["data"]
            self.assertEqual(data_detail["total_amount"], 16000.0)
            self.assertEqual(data_detail["lines"][0]["price_unit"], 8000.0)
            self.assertEqual(data_detail["lines"][0]["subtotal"], 16000.0)

    def test_10_negative_and_zero_quantity_rejected(self):
        """Validasi kuantitas tidak boleh nol atau negatif."""
        # Kuantitas nol
        payload_zero = {
            "partner_id": self.partner.id,
            "lines": [{"product_id": self.srv_kg.id, "quantity": 0}],
        }
        mock_req_zero = self._mock_request(user=self.admin_user, data=payload_zero)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req_zero):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 400)

        # Kuantitas negatif
        payload_neg = {
            "partner_id": self.partner.id,
            "lines": [{"product_id": self.srv_kg.id, "quantity": -2}],
        }
        mock_req_neg = self._mock_request(user=self.admin_user, data=payload_neg)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req_neg):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 400)

    def test_11_carpet_zero_and_negative_dimensions_rejected(self):
        """Validasi panjang dan lebar karpet harus positif (> 0)."""
        # Panjang 0
        payload_len_zero = {
            "partner_id": self.partner.id,
            "lines": [{"product_id": self.srv_carpet.id, "length": 0, "width": 2}],
        }
        mock_len_zero = self._mock_request(user=self.admin_user, data=payload_len_zero)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_len_zero):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 400)

        # Lebar negatif
        payload_width_neg = {
            "partner_id": self.partner.id,
            "lines": [{"product_id": self.srv_carpet.id, "length": 2, "width": -1}],
        }
        mock_width_neg = self._mock_request(user=self.admin_user, data=payload_width_neg)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_width_neg):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 400)

    def test_12_incompatible_uom_rejected(self):
        """Validasi satuan UoM harus sesuai dan kompatibel dengan produk layanan."""
        payload = {
            "partner_id": self.partner.id,
            "lines": [
                {
                    "product_id": self.srv_kg.id,
                    "quantity": 2.0,
                    "uom_id": self.uom_liter.id,  # Cuci Kiloan dikirim satuan Liter -> tidak kompatibel
                }
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.handle_orders()
            self.assertEqual(res.status_code, 400)
            body = json.loads(res.get_data(as_text=True))
            self.assertFalse(body["success"])
            self.assertIn("tidak kompatibel", body["message"])

    def test_13_get_orders_list_and_filter(self):
        """Uji endpoint list order GET /api/laundry/orders."""
        mock_req = self._mock_request(user=self.admin_user, method="GET", params={"partner_id": str(self.partner.id)})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.get_orders(partner_id=str(self.partner.id))
            self.assertEqual(res.status_code, 200)
            body = json.loads(res.get_data(as_text=True))
            self.assertTrue(body["success"])
            self.assertIsInstance(body["data"], list)

