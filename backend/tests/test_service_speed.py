import json
from unittest.mock import MagicMock, patch
from odoo.exceptions import ValidationError
from odoo.tests.common import TransactionCase
from ..controllers.order_controller import OrderApiController


class TestServiceSpeed(TransactionCase):
    """
    Unit test suite untuk Pilihan Kecepatan Pengerjaan (Reguler & Same Day Service) - Tugas 7.
    Skenario:
    1. Order Reguler (berhasil, tanpa biaya tambahan).
    2. Same Day tersedia (berhasil, mengambil biaya dari konfigurasi Odoo jika ada).
    3. Same Day tidak tersedia (backend menolak pembuatan order Same Day).
    4. Pilihan jenis pengerjaan tidak valid (backend menolak pilihan selain regular & same_day).
    5. Immutabilitas transaksi lama (perubahan konfigurasi tidak mengubah transaksi yang sudah dibuat).
    6. Pengujian API Endpoint GET /api/laundry/service-speeds dan POST /api/laundry/orders.
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.controller = OrderApiController()
        cls.admin_user = cls.env.ref("base.user_admin")
        cls.public_user = cls.env.ref("base.public_user")

        cls.partner = cls.env["res.partner"].create({
            "name": "Pelanggan Prioritas",
            "phone": "081234567891",
        })

        cls.uom_kg = cls.env["uom.uom"].search([("name", "=", "kg")], limit=1) or cls.env["uom.uom"].browse(16)
        cls.cat_service = cls.env["product.category"].search([("name", "=", "Layanan Laundry")], limit=1)
        if not cls.cat_service:
            cls.cat_service = cls.env["product.category"].create({"name": "Layanan Laundry"})

        cls.srv_wash = cls.env["product.template"].create({
            "name": "Cuci Lipat Kilat",
            "default_code": "SRV-TEST-SPEED-01",
            "type": "service",
            "list_price": 8000.0,
            "uom_id": cls.uom_kg.id,
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

    def _mock_request(self, user=None, data=None):
        mock_req = MagicMock()
        mock_req.env = self.env(user=user) if user else self.env(user=self.public_user)
        mock_req.session = MagicMock()
        mock_req.session.uid = user.id if user else None
        mock_req.session.sid = "test_session_id"
        mock_req.httprequest = MagicMock()
        mock_req.httprequest.headers = {}
        mock_req.httprequest.method = "GET"
        mock_req.params = {}
        if data is not None:
            mock_req.httprequest.method = "POST"
            mock_req.httprequest.data = json.dumps(data).encode("utf-8")
        return mock_req

    def test_01_order_reguler_success(self):
        """Skenario 1: Order Reguler (default, berhasil dibuat tanpa biaya tambahan)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "service_speed": "regular",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_wash.id,
                "quantity": 2.0,  # 2 kg * 8000 = 16000
            })],
        })

        self.assertEqual(order.service_speed, "regular")
        self.assertEqual(order.service_speed_fee, 0.0)
        self.assertEqual(order.total_amount, 16000.0)

    def test_02_same_day_tersedia_success_with_surcharge(self):
        """
        Skenario 2: Same Day tersedia.
        Admin mengaktifkan Same Day dengan biaya tambahan yang sudah dikonfirmasi di konfigurasi Odoo.
        """
        # Set konfigurasi Same Day aktif dengan biaya Rp5.000
        self.env["laundry.order"].set_same_day_config(available=True, surcharge=5000.0)
        self.assertTrue(self.env["laundry.order"].is_same_day_available())
        self.assertEqual(self.env["laundry.order"].get_same_day_surcharge(), 5000.0)

        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "service_speed": "same_day",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_wash.id,
                "quantity": 2.0,  # 2 kg * 8000 = 16000
            })],
        })

        self.assertEqual(order.service_speed, "same_day")
        self.assertEqual(order.service_speed_fee, 5000.0)
        # Total = 16000 + 5000 = 21000
        self.assertEqual(order.total_amount, 21000.0)

    def test_03_same_day_tersedia_without_surcharge_before_confirmed(self):
        """
        Ketentuan 7: Jangan menambahkan biaya tambahan sebelum tarif dikonfirmasi.
        Jika biaya surcharge bernilai 0.0, tidak ada biaya tambahan yang ditambahkan.
        """
        self.env["laundry.order"].set_same_day_config(available=True, surcharge=0.0)

        order = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "service_speed": "same_day",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_wash.id,
                "quantity": 3.0,  # 3 * 8000 = 24000
            })],
        })

        self.assertEqual(order.service_speed, "same_day")
        self.assertEqual(order.service_speed_fee, 0.0)
        self.assertEqual(order.total_amount, 24000.0)

    def test_04_same_day_tidak_tersedia_rejected(self):
        """
        Skenario 3: Same Day tidak tersedia.
        Backend menolak pilihan Same Day jika ketersediaan sedang dinonaktifkan oleh admin.
        """
        self.env["laundry.order"].set_same_day_config(available=False, surcharge=10000.0)
        self.assertFalse(self.env["laundry.order"].is_same_day_available())

        with self.assertRaises(ValidationError) as cm:
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "service_speed": "same_day",
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_wash.id,
                    "quantity": 2.0,
                })],
            })
        self.assertIn("Layanan Same Day Service sedang tidak tersedia", str(cm.exception))

    def test_05_pilihan_tidak_valid_rejected(self):
        """
        Skenario 4: Pilihan tidak valid.
        Backend menolak pilihan kecepatan selain 'regular' dan 'same_day'.
        """
        # Pilihan 'instant'
        with self.assertRaises(ValidationError) as cm1:
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "service_speed": "instant",
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_wash.id,
                    "quantity": 2.0,
                })],
            })
        self.assertIn("Pilihan jenis pengerjaan", str(cm1.exception))

        # Pilihan 'express_super'
        with self.assertRaises(ValidationError) as cm2:
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "service_speed": "express_super",
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_wash.id,
                    "quantity": 2.0,
                })],
            })
        self.assertIn("Pilihan jenis pengerjaan", str(cm2.exception))

    def test_06_configuration_change_immutability(self):
        """
        Ketentuan 10: Perubahan konfigurasi tidak boleh mengubah order lama.
        """
        # 1. Buat pesanan Same Day saat biaya Rp5.000
        self.env["laundry.order"].set_same_day_config(available=True, surcharge=5000.0)
        order_old = self.env["laundry.order"].create({
            "partner_id": self.partner.id,
            "service_speed": "same_day",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_wash.id,
                "quantity": 2.0,  # 16000 + 5000 = 21000
            })],
        })
        self.assertEqual(order_old.service_speed_fee, 5000.0)
        self.assertEqual(order_old.total_amount, 21000.0)

        # 2. Admin mengubah tarif menjadi Rp15.000 dan menonaktifkan Same Day
        self.env["laundry.order"].set_same_day_config(available=False, surcharge=15000.0)

        # 3. Hitung ulang order lama
        order_old.recompute_prices()
        order_old.invalidate_recordset()

        # Order lama HARUS TETAP Rp5.000 biaya dan Rp21.000 total
        self.assertEqual(order_old.service_speed_fee, 5000.0)
        self.assertEqual(order_old.total_amount, 21000.0)

        # Order lama tetap dapat diperbarui catatannya tanpa error
        order_old.write({"notes": "Catatan update pelanggan lama"})
        self.assertEqual(order_old.notes, "Catatan update pelanggan lama")

        # 4. Tetapi pembuatan order BARU dengan same_day ditolak karena saat ini tidak tersedia
        with self.assertRaises(ValidationError):
            self.env["laundry.order"].create({
                "partner_id": self.partner.id,
                "service_speed": "same_day",
                "line_ids": [(0, 0, {
                    "product_template_id": self.srv_wash.id,
                    "quantity": 2.0,
                })],
            })

    def test_07_api_endpoint_service_speeds(self):
        """Pengujian endpoint GET /api/laundry/service-speeds."""
        self.env["laundry.order"].set_same_day_config(available=True, surcharge=7500.0)

        # 1. Request tidak diautentikasi -> 401
        mock_unauth = self._mock_request(user=None)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_unauth):
            res_unauth = self.controller.get_service_speeds()
            self.assertEqual(res_unauth.status_code, 401)

        # 2. Request terautentikasi -> 200 dengan daftar pilihan
        mock_auth = self._mock_request(user=self.admin_user)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_auth):
            res_auth = self.controller.get_service_speeds()
            self.assertEqual(res_auth.status_code, 200)
            body = json.loads(res_auth.get_data(as_text=True))
            self.assertTrue(body["success"])
            self.assertEqual(body["count"], 2)

            speed_map = {s["code"]: s for s in body["data"]}
            self.assertIn("regular", speed_map)
            self.assertIn("same_day", speed_map)
            self.assertTrue(speed_map["regular"]["available"])
            self.assertEqual(speed_map["regular"]["fee"], 0.0)
            self.assertTrue(speed_map["same_day"]["available"])
            self.assertEqual(speed_map["same_day"]["fee"], 7500.0)

    def test_08_api_endpoint_create_order(self):
        """Pengujian endpoint POST /api/laundry/orders."""
        # 1. Same Day Aktif
        self.env["laundry.order"].set_same_day_config(available=True, surcharge=5000.0)
        payload_same_day = {
            "partner_id": self.partner.id,
            "service_speed": "same_day",
            "lines": [
                {
                    "product_template_id": self.srv_wash.id,
                    "quantity": 2.0,
                }
            ],
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload_same_day)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req):
            res = self.controller.create_order()
            self.assertEqual(res.status_code, 201)
            body = json.loads(res.get_data(as_text=True))
            self.assertTrue(body["success"])
            self.assertEqual(body["data"]["service_speed"], "same_day")
            self.assertEqual(body["data"]["service_speed_fee"], 5000.0)
            self.assertEqual(body["data"]["total_amount"], 21000.0)

        # 2. Same Day Tidak Aktif -> Ditolak 400
        self.env["laundry.order"].set_same_day_config(available=False, surcharge=5000.0)
        mock_req_disabled = self._mock_request(user=self.admin_user, data=payload_same_day)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req_disabled):
            res_disabled = self.controller.create_order()
            self.assertEqual(res_disabled.status_code, 400)
            body_disabled = json.loads(res_disabled.get_data(as_text=True))
            self.assertFalse(body_disabled["success"])

        # 3. Pilihan Tidak Valid -> Ditolak 400
        payload_invalid = {
            "partner_id": self.partner.id,
            "service_speed": "invalid_speed_turbo",
            "lines": [{"product_template_id": self.srv_wash.id, "quantity": 1.0}],
        }
        mock_req_invalid = self._mock_request(user=self.admin_user, data=payload_invalid)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req_invalid):
            res_invalid = self.controller.create_order()
            self.assertEqual(res_invalid.status_code, 400)
            body_invalid = json.loads(res_invalid.get_data(as_text=True))
            self.assertFalse(body_invalid["success"])
