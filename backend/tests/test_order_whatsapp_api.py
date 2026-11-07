# -*- coding: utf-8 -*-
import json
from unittest.mock import MagicMock, patch
from odoo.tests.common import TransactionCase
from ..controllers.order_controller import OrderApiController


class TestOrderWhatsappApi(TransactionCase):
    """
    Automated Integration Test Suite untuk WhatsApp API LaundryFlow:
    - POST /api/orders/<id>/send-whatsapp & /api/laundry/orders/<id>/send-whatsapp
    - GET  /api/orders/<id>/whatsapp-status & /api/laundry/orders/<id>/whatsapp-status
    - GET  /api/orders/<id>/whatsapp-preview & /api/laundry/orders/<id>/whatsapp-preview
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.controller = OrderApiController()
        cls.admin_user = cls.env.ref("base.user_admin")
        cls.public_user = cls.env.ref("base.public_user")

        # Operator Internal User
        group_user = cls.env.ref("base.group_user")
        cls.operator_user = cls.env["res.users"].create({
            "name": "Operator WhatsApp API Test",
            "login": "operator_wa_test@laundryflow.com",
            "email": "operator_wa_test@laundryflow.com",
            "group_ids": [(6, 0, [group_user.id])],
        })

        # Customer 1 (Main test customer with phone)
        cls.partner_customer = cls.env["res.partner"].create({
            "name": "Pelanggan WA Test",
            "phone": "081234567890",
        })

        # Customer 2 (Other customer)
        cls.partner_customer_2 = cls.env["res.partner"].create({
            "name": "Pelanggan WA Test Lain",
            "phone": "081299998888",
        })

        # Portal User for Customer 1
        group_portal = cls.env.ref("base.group_portal")
        cls.portal_user = cls.env["res.users"].create({
            "name": "Portal Customer WA Test",
            "login": "portal_wa_test@laundryflow.com",
            "email": "portal_wa_test@laundryflow.com",
            "partner_id": cls.partner_customer.id,
            "group_ids": [(6, 0, [group_portal.id])],
        })

        # Service Product for Line
        cls.uom_kg = cls.env["uom.uom"].search([("name", "=", "kg")], limit=1) or cls.env["uom.uom"].browse(16)
        cls.cat_service = cls.env["product.category"].search([("name", "=", "Layanan Laundry")], limit=1)
        if not cls.cat_service:
            cls.cat_service = cls.env["product.category"].create({"name": "Layanan Laundry"})

        cls.service_product = cls.env["product.template"].create({
            "name": "Cuci Lipat Reguler WA Test",
            "default_code": "SRV-WA-01",
            "type": "service",
            "list_price": 7000.0,
            "uom_id": cls.uom_kg.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })

    def setUp(self):
        super().setUp()
        # Mock send_message dan send_message_immediate pada active model class di registry Odoo
        outbox_cls = type(self.env["infinys.wapi.outbox"])
        def _mock_send(outbox_record):
            outbox_record.write({"is_delivered": True, "error_msg": False})
            return True

        self.patcher1 = patch.object(outbox_cls, "send_message_immediate", autospec=True, side_effect=_mock_send)
        self.patcher2 = patch.object(outbox_cls, "send_message", autospec=True, side_effect=_mock_send)
        self.patcher1.start()
        self.patcher2.start()
        self.addCleanup(self.patcher1.stop)
        self.addCleanup(self.patcher2.stop)

        # Buat pesanan standar untuk pengujian
        self.order = self.env["laundry.order"].with_context(skip_whatsapp_notification=True).create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "pickup",
            "weight": 2.5,
            "line_ids": [(0, 0, {
                "product_template_id": self.service_product.id,
                "quantity": 2.5,
            })]
        })

    def _mock_request(self, user=None, data=None, method="POST", kwargs=None):
        """Helper mock HTTP Request Odoo."""
        mock_req = MagicMock()
        mock_req.httprequest.method = method
        mock_req.httprequest.headers = {}
        mock_req.params = kwargs or {}
        mock_req.session = MagicMock()
        mock_req.session.uid = user.id if user else None
        mock_req.session.sid = "mock_session_id_wa_api_test"
        mock_req.db = self.env.cr.dbname
        mock_req.env = self.env(user=user) if user else self.env(user=self.public_user)

        if data is not None:
            if isinstance(data, (dict, list)):
                mock_req.httprequest.data = json.dumps(data).encode("utf-8")
            elif isinstance(data, str):
                mock_req.httprequest.data = data.encode("utf-8")
        else:
            mock_req.httprequest.data = b""

        return mock_req

    def test_01_send_whatsapp_invoice_success(self):
        """1. POST /api/orders/<id>/send-whatsapp berhasil mengirim nota (invoice)."""
        mock_req = self._mock_request(user=self.admin_user, data={"template": "invoice"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.send_order_whatsapp(self.order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertTrue(res_data.get("success"))
            self.assertEqual(res_data["data"]["template_used"], "invoice")
            self.assertEqual(res_data["data"]["recipient_phone"], "6281234567890")
            self.assertIn(res_data["data"]["whatsapp_status"], ["pending", "delivered"])

    def test_02_send_whatsapp_ready_success(self):
        """2. POST /api/orders/<id>/send-whatsapp berhasil mengirim pemberitahuan pesanan siap (ready)."""
        mock_req = self._mock_request(user=self.operator_user, data={"template": "ready"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.operator_user):
            resp = self.controller.send_order_whatsapp(self.order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertTrue(res_data.get("success"))
            self.assertEqual(res_data["data"]["template_used"], "ready")

    def test_03_send_whatsapp_reminder_success(self):
        """3. POST /api/orders/<id>/send-whatsapp berhasil mengirim pesan pengingat (reminder)."""
        mock_req = self._mock_request(user=self.admin_user, data={"template": "reminder"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.send_order_whatsapp(self.order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertTrue(res_data.get("success"))
            self.assertEqual(res_data["data"]["template_used"], "reminder")

    def test_04_send_whatsapp_custom_success(self):
        """4. POST /api/orders/<id>/send-whatsapp berhasil mengirim pesan kustom."""
        mock_req = self._mock_request(user=self.operator_user, data={
            "template": "custom",
            "custom_message": "Pakaian Anda telah selesai dicuci dan disemprot pewangi lavender."
        })
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.operator_user):
            resp = self.controller.send_order_whatsapp(self.order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertTrue(res_data.get("success"))
            self.assertEqual(res_data["data"]["template_used"], "custom")

    def test_05_send_whatsapp_custom_missing_text_400(self):
        """5. Template 'custom' tanpa pesan mengembalikan HTTP 400 Bad Request."""
        mock_req = self._mock_request(user=self.operator_user, data={
            "template": "custom",
            "custom_message": ""
        })
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.operator_user):
            resp = self.controller.send_order_whatsapp(self.order.id)
            self.assertEqual(resp.status_code, 400)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertFalse(res_data.get("success"))

    def test_06_send_whatsapp_invalid_template_400(self):
        """6. Template tidak valid mengembalikan HTTP 400 Bad Request."""
        mock_req = self._mock_request(user=self.admin_user, data={"template": "promo_diskon"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.send_order_whatsapp(self.order.id)
            self.assertEqual(resp.status_code, 400)

    def test_07_send_whatsapp_invalid_phone_400(self):
        """7. Nomor telepon override tidak valid mengembalikan HTTP 400."""
        mock_req = self._mock_request(user=self.operator_user, data={
            "template": "invoice",
            "phone": "12345"
        })
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.operator_user):
            resp = self.controller.send_order_whatsapp(self.order.id)
            self.assertEqual(resp.status_code, 400)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertFalse(res_data.get("success"))

    def test_08_send_whatsapp_unauthorized_401(self):
        """8. Request tanpa kredensial autentikasi mengembalikan HTTP 401 Unauthorized."""
        mock_req = self._mock_request(user=None)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=None):
            resp = self.controller.send_order_whatsapp(self.order.id)
            self.assertEqual(resp.status_code, 401)

    def test_09_send_whatsapp_forbidden_for_portal_403(self):
        """9. Pengguna Portal (Customer) dilarang memicu pengiriman WhatsApp (HTTP 403 Forbidden)."""
        mock_req = self._mock_request(user=self.portal_user)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.portal_user):
            resp = self.controller.send_order_whatsapp(self.order.id)
            self.assertEqual(resp.status_code, 403)

    def test_10_send_whatsapp_order_not_found_404(self):
        """10. ID pesanan tidak ada di database mengembalikan HTTP 404 Not Found."""
        mock_req = self._mock_request(user=self.admin_user)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.send_order_whatsapp(999999)
            self.assertEqual(resp.status_code, 404)

    def test_11_get_whatsapp_status_success(self):
        """11. GET /api/orders/<id>/whatsapp-status mengembalikan riwayat outbox dan status terkini."""
        # Kirim satu pesan terlebih dahulu
        self.order.action_send_whatsapp_notification(template_type="invoice")

        mock_req = self._mock_request(user=self.admin_user, method="GET")
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.get_order_whatsapp_status(self.order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertTrue(res_data.get("success"))
            self.assertEqual(res_data["data"]["order_id"], self.order.id)
            self.assertTrue(res_data["data"]["whatsapp_sent"])
            self.assertGreaterEqual(res_data["data"]["outbox_count"], 1)
            self.assertIsInstance(res_data["data"]["history"], list)

    def test_12_get_whatsapp_status_portal_own_order_200(self):
        """12. Pengguna Portal diizinkan melihat status WhatsApp pesanan miliknya sendiri (HTTP 200)."""
        mock_req = self._mock_request(user=self.portal_user, method="GET")
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.portal_user):
            resp = self.controller.get_order_whatsapp_status(self.order.id)
            self.assertEqual(resp.status_code, 200)

    def test_13_get_whatsapp_status_portal_other_order_403(self):
        """13. Pengguna Portal dilarang melihat status WhatsApp pesanan orang lain (HTTP 403 Forbidden)."""
        other_order = self.env["laundry.order"].with_context(skip_whatsapp_notification=True).create({
            "partner_id": self.partner_customer_2.id,
            "weight": 1.0,
            "line_ids": [(0, 0, {
                "product_template_id": self.service_product.id,
                "quantity": 1.0,
            })]
        })
        mock_req = self._mock_request(user=self.portal_user, method="GET")
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.portal_user):
            resp = self.controller.get_order_whatsapp_status(other_order.id)
            self.assertEqual(resp.status_code, 403)

    def test_14_preview_whatsapp_invoice_200(self):
        """14. GET /api/orders/<id>/whatsapp-preview mengembalikan teks nota terformat tanpa mengirim pesan."""
        mock_req = self._mock_request(user=self.operator_user, method="GET")
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.operator_user):
            resp = self.controller.preview_order_whatsapp(self.order.id, template="invoice")
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertTrue(res_data.get("success"))
            self.assertIn("NOTA PESANAN", res_data["data"]["message"])
            self.assertGreater(res_data["data"]["character_count"], 50)
            self.assertEqual(res_data["data"]["recipient_phone"], "6281234567890")

    def test_15_preview_whatsapp_custom_200(self):
        """15. GET /api/orders/<id>/whatsapp-preview pratinjau pesan kustom."""
        mock_req = self._mock_request(user=self.operator_user, method="GET")
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.operator_user):
            resp = self.controller.preview_order_whatsapp(
                self.order.id,
                template="custom",
                custom_message="Halo, karpet Anda sedang dijemur."
            )
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertIn("sedang dijemur", res_data["data"]["message"])

    def test_16_preview_whatsapp_invalid_phone_override_400(self):
        """16. Pratinjau dengan nomor override tidak valid mengembalikan HTTP 400."""
        mock_req = self._mock_request(user=self.operator_user, method="GET")
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.operator_user):
            resp = self.controller.preview_order_whatsapp(self.order.id, phone="invalid_num")
            self.assertEqual(resp.status_code, 400)

    def test_17_preview_whatsapp_portal_forbidden_403(self):
        """17. Portal user dilarang mengakses endpoint pratinjau WhatsApp (HTTP 403 Forbidden)."""
        mock_req = self._mock_request(user=self.portal_user, method="GET")
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), \
             patch.object(self.controller, "_get_authenticated_user", return_value=self.portal_user):
            resp = self.controller.preview_order_whatsapp(self.order.id)
            self.assertEqual(resp.status_code, 403)
