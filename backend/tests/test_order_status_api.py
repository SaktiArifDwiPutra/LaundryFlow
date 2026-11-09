# -*- coding: utf-8 -*-
import json
from unittest.mock import MagicMock, patch
from odoo.tests.common import TransactionCase
from ..controllers.order_controller import OrderApiController


class TestOrderStatusApi(TransactionCase):
    """
    Automated test suite untuk Endpoint Pembaruan Status Pesanan Laundry (Task 2):
    PATCH /api/laundry/orders/<order_id>/status
    PATCH /api/orders/<order_id>/status

    Cakupan Pengujian:
    1. received -> washing (HTTP 200)
    2. washing -> drying (HTTP 200)
    3. drying -> ironing (HTTP 200)
    4. ironing -> ready (HTTP 200)
    5. received -> ironing untuk Setrika Saja (HTTP 200)
    6. ready -> completed untuk pickup (HTTP 200)
    7. ready -> out_for_delivery untuk delivery (HTTP 200)
    8. out_for_delivery -> completed (HTTP 200)
    9. Transisi yang melompati tahapan -> HTTP 409 Conflict
    10. Status tujuan tidak dikenal / kosong -> HTTP 400 Bad Request
    11. ID pesanan tidak ditemukan -> HTTP 404 Not Found
    12. Customer/portal tidak memiliki izin memperbarui status -> HTTP 403 Forbidden
    13. Operator / Admin internal berhasil memperbarui status -> HTTP 200 OK
    14. Pembatalan melalui endpoint (to: cancelled) -> HTTP 200 OK
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.controller = OrderApiController()
        cls.admin_user = cls.env.ref("base.user_admin")
        cls.public_user = cls.env.ref("base.public_user")

        # Operator Internal
        group_user = cls.env.ref("base.group_user")
        cls.operator_user = cls.env["res.users"].create({
            "name": "Operator Laundry Status Test",
            "login": "operator_status_test@laundryflow.com",
            "email": "operator_status_test@laundryflow.com",
            "group_ids": [(6, 0, [group_user.id])],
        })

        # Customer Portal
        cls.partner_customer = cls.env["res.partner"].create({
            "name": "Pelanggan Status Test",
            "phone": "081299988877",
        })
        group_portal = cls.env.ref("base.group_portal")
        cls.portal_user = cls.env["res.users"].create({
            "name": "Portal Customer Status Test",
            "login": "portal_customer_status_test@laundryflow.com",
            "email": "portal_customer_status_test@laundryflow.com",
            "partner_id": cls.partner_customer.id,
            "group_ids": [(6, 0, [group_portal.id])],
        })

        # Master Data Layanan
        cls.uom_kg = cls.env["uom.uom"].search([("name", "=", "kg")], limit=1) or cls.env["uom.uom"].browse(16)
        cls.cat_service = cls.env["product.category"].search([("name", "=", "Layanan Laundry")], limit=1)
        if not cls.cat_service:
            cls.cat_service = cls.env["product.category"].create({"name": "Layanan Laundry"})

        cls.srv_cuci_setrika = cls.env["product.template"].create({
            "name": "Cuci Setrika Express Status",
            "default_code": "SRV-STS-WIR-01",
            "type": "service",
            "list_price": 10000.0,
            "uom_id": cls.uom_kg.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })

        cls.srv_setrika_saja = cls.env["product.template"].create({
            "name": "Setrika Saja Kilat Status",
            "default_code": "SRV-STS-IRN-01",
            "type": "service",
            "list_price": 6000.0,
            "uom_id": cls.uom_kg.id,
            "categ_id": cls.cat_service.id,
            "sale_ok": True,
        })

    def _mock_request(self, user=None, data=None, method="PATCH", headers=None):
        """Helper membuat mock context request Odoo."""
        mock_req = MagicMock()
        mock_req.httprequest.method = method
        mock_req.httprequest.headers = headers or {}
        mock_req.params = {}
        mock_req.session = MagicMock()
        mock_req.session.uid = user.id if user else None
        mock_req.session.sid = "mock_session_id_status_test"
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

    def test_01_received_to_washing(self):
        """1. received -> washing berhasil (HTTP 200)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "pickup",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 3.0,
            })]
        })
        mock_req = self._mock_request(user=self.admin_user, data={"to": "washing"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertTrue(res_data.get("success"))
            self.assertEqual(res_data["data"]["previous_status"], "received")
            self.assertEqual(res_data["data"]["current_status"], "washing")
            self.assertEqual(res_data["data"]["next_status"], "drying")
            self.assertIn("washing", res_data["data"]["stages"])

    def test_02_washing_to_drying(self):
        """2. washing -> drying berhasil (HTTP 200)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "pickup",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 3.0,
            })]
        })
        order.action_washing()

        mock_req = self._mock_request(user=self.admin_user, data={"to": "drying"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertEqual(res_data["data"]["previous_status"], "washing")
            self.assertEqual(res_data["data"]["current_status"], "drying")
            self.assertEqual(res_data["data"]["next_status"], "ironing")

    def test_03_drying_to_ironing(self):
        """3. drying -> ironing berhasil (HTTP 200)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "pickup",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 3.0,
            })]
        })
        order.action_washing()
        order.action_drying()

        mock_req = self._mock_request(user=self.admin_user, data={"to": "ironing"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertEqual(res_data["data"]["previous_status"], "drying")
            self.assertEqual(res_data["data"]["current_status"], "ironing")
            self.assertEqual(res_data["data"]["next_status"], "ready")

    def test_04_ironing_to_ready(self):
        """4. ironing -> ready berhasil (HTTP 200)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "pickup",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 3.0,
            })]
        })
        order.action_washing()
        order.action_drying()
        order.action_ironing()

        mock_req = self._mock_request(user=self.admin_user, data={"to": "ready"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertEqual(res_data["data"]["previous_status"], "ironing")
            self.assertEqual(res_data["data"]["current_status"], "ready")
            self.assertEqual(res_data["data"]["next_status"], "completed")

    def test_05_received_to_ironing_for_setrika_saja(self):
        """5. received -> ironing untuk Setrika Saja berhasil (HTTP 200)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "pickup",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_setrika_saja.id,
                "quantity": 2.0,
            })]
        })
        mock_req = self._mock_request(user=self.admin_user, data={"to": "ironing"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertEqual(res_data["data"]["previous_status"], "received")
            self.assertEqual(res_data["data"]["current_status"], "ironing")
            self.assertEqual(res_data["data"]["next_status"], "ready")

    def test_06_ready_to_completed_for_pickup(self):
        """6. ready -> completed untuk pickup berhasil (HTTP 200)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "pickup",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_setrika_saja.id,
                "quantity": 1.0,
            })]
        })
        order.action_ironing()
        order.action_ready()

        mock_req = self._mock_request(user=self.admin_user, data={"to": "completed"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertEqual(res_data["data"]["previous_status"], "ready")
            self.assertEqual(res_data["data"]["current_status"], "completed")
            self.assertIsNone(res_data["data"]["next_status"])

    def test_07_ready_to_out_for_delivery(self):
        """7. ready -> out_for_delivery untuk delivery berhasil (HTTP 200)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "delivery",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_setrika_saja.id,
                "quantity": 1.0,
            })]
        })
        order.action_ironing()
        order.action_ready()

        mock_req = self._mock_request(user=self.admin_user, data={"to": "out_for_delivery"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertEqual(res_data["data"]["previous_status"], "ready")
            self.assertEqual(res_data["data"]["current_status"], "out_for_delivery")
            self.assertEqual(res_data["data"]["next_status"], "completed")

    def test_08_out_for_delivery_to_completed(self):
        """8. out_for_delivery -> completed untuk delivery berhasil (HTTP 200)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "delivery",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_setrika_saja.id,
                "quantity": 1.0,
            })]
        })
        order.action_ironing()
        order.action_ready()
        order.action_out_for_delivery()

        mock_req = self._mock_request(user=self.admin_user, data={"to": "completed"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertEqual(res_data["data"]["previous_status"], "out_for_delivery")
            self.assertEqual(res_data["data"]["current_status"], "completed")
            self.assertIsNone(res_data["data"]["next_status"])

    def test_09_stage_skipping_returns_409_conflict(self):
        """9. Transisi yang melompati tahapan harus mengembalikan HTTP 409 Conflict."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "pickup",
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 2.0,
            })]
        })
        # Lompat langsung dari received ke completed
        mock_req = self._mock_request(user=self.admin_user, data={"to": "completed"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 409)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertFalse(res_data.get("success"))

        # Lompat langsung dari received ke ready
        mock_req = self._mock_request(user=self.admin_user, data={"to": "ready"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 409)

    def test_10_unknown_and_empty_status_rejected(self):
        """10. Status tidak dikenal atau kosong harus ditolak (HTTP 400)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 1.0,
            })]
        })
        # Status tidak dikenal
        mock_req = self._mock_request(user=self.admin_user, data={"to": "terbang"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 400)

        # Status kosong
        mock_req = self._mock_request(user=self.admin_user, data={"to": ""})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 400)

    def test_11_order_not_found_returns_404(self):
        """11. ID pesanan tidak ditemukan harus mengembalikan HTTP 404."""
        non_existent_id = 99999999
        mock_req = self._mock_request(user=self.admin_user, data={"to": "washing"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(non_existent_id)
            self.assertEqual(resp.status_code, 404)

    def test_12_portal_customer_forbidden_403(self):
        """12. Customer portal tidak memiliki izin memperbarui status (HTTP 403)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 2.0,
            })]
        })
        mock_req = self._mock_request(user=self.portal_user, data={"to": "washing"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.portal_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 403)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertFalse(res_data.get("success"))

    def test_13_operator_user_success(self):
        """13. Operator internal yang berwenang berhasil memperbarui status (HTTP 200)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 3.0,
            })]
        })
        mock_req = self._mock_request(user=self.operator_user, data={"to": "washing"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.operator_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertTrue(res_data.get("success"))
            self.assertEqual(res_data["data"]["current_status"], "washing")

    def test_14_cancel_order_via_endpoint(self):
        """14. Pembatalan pesanan melalui endpoint (to: cancelled) berhasil (HTTP 200)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 1.0,
            })]
        })
        mock_req = self._mock_request(user=self.admin_user, data={"to": "cancelled"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_status(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertEqual(res_data["data"]["current_status"], "cancelled")
            self.assertIsNone(res_data["data"]["next_status"])

    def test_15_update_order_delivery_success(self):
        """15. Update delivery dari pickup ke delivery berhasil memperbarui alamat, ongkir, total, dan tahapan."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "delivery_type": "pickup",
            "delivery_fee": 0.0,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 2.0,
            })]
        })
        base_total = order.total_amount
        mock_req = self._mock_request(user=self.admin_user, data={
            "delivery_type": "delivery",
            "delivery_address": "Jl. Mawar No. 10, Jakarta Selatan",
            "delivery_fee": 15000.0,
            "notes": "Tolong diantar sore",
        })
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_delivery(order.id)
            self.assertEqual(resp.status_code, 200)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertTrue(res_data.get("success"))
            data = res_data["data"]
            self.assertEqual(data["delivery_type"], "delivery")
            self.assertEqual(data["delivery_address"], "Jl. Mawar No. 10, Jakarta Selatan")
            self.assertEqual(data["delivery_fee"], 15000.0)
            self.assertEqual(data["total_amount"], base_total + 15000.0)
            self.assertIn("out_for_delivery", data["stages"])

    def test_16_update_order_delivery_portal_forbidden(self):
        """16. Pelanggan portal dilarang mengakses update delivery (HTTP 403)."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 1.0,
            })]
        })
        mock_req = self._mock_request(user=self.portal_user, data={"delivery_type": "delivery"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.portal_user):
            resp = self.controller.update_order_delivery(order.id)
            self.assertEqual(resp.status_code, 403)

    def test_17_update_order_delivery_invalid_type(self):
        """17. delivery_type tidak valid menghasilkan HTTP 400."""
        order = self.env["laundry.order"].create({
            "partner_id": self.partner_customer.id,
            "line_ids": [(0, 0, {
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 1.0,
            })]
        })
        mock_req = self._mock_request(user=self.admin_user, data={"delivery_type": "drone_delivery"})
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.update_order_delivery(order.id)
            self.assertEqual(resp.status_code, 400)

    def test_18_reject_internal_staff_as_order_partner(self):
        """18. Validasi penolakan staf internal/admin sebagai pelanggan pesanan (HTTP 400)."""
        admin_partner_id = self.admin_user.partner_id.id
        payload = {
            "partner_id": admin_partner_id,
            "lines": [{
                "product_template_id": self.srv_cuci_setrika.id,
                "quantity": 1.0,
            }]
        }
        mock_req = self._mock_request(user=self.admin_user, data=payload)
        with patch("odoo.addons.laundryflow_backend.controllers.order_controller.request", mock_req), patch.object(self.controller, "_get_authenticated_user", return_value=self.admin_user):
            resp = self.controller.create_order()
            self.assertEqual(resp.status_code, 400)
            res_data = json.loads(resp.data.decode("utf-8"))
            self.assertFalse(res_data.get("success"))
            self.assertEqual(res_data.get("message"), "Akun staf/admin tidak dapat dipilih sebagai pelanggan pesanan.")
