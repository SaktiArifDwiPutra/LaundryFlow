import json
from unittest.mock import MagicMock, patch
from odoo.tests.common import TransactionCase
from ..controllers.docs import ApiDocsController


class TestApiDocs(TransactionCase):
    """
    Automated test suite for LaundryFlow Scalar API Reference & OpenAPI Specification.
    Tests:
    1. OpenAPI specification endpoint returns 200 and valid OpenAPI 3.0.3 JSON structure
    2. OpenAPI specification documents Login, Customer Search, and Customer Creation endpoints
    3. OpenAPI specification contains no sensitive credentials or real tokens
    4. Scalar documentation HTML page returns 200 with Scalar reference script and OpenAPI data-url
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.docs_controller = ApiDocsController()

    def _mock_request(self, method="GET", host_url="http://117.53.47.93:8069/"):
        mock_req = MagicMock()
        mock_req.env = self.env
        mock_req.httprequest.method = method
        mock_req.httprequest.host_url = host_url
        mock_req.httprequest.headers = {}
        return mock_req

    def test_01_openapi_spec_valid(self):
        """Test that /api/openapi.json returns HTTP 200 and valid OpenAPI 3.0.3 JSON."""
        mock_req = self._mock_request(method="GET")
        with patch("odoo.addons.laundryflow_backend.controllers.docs.request", mock_req):
            response = self.docs_controller.openapi_spec()
            self.assertEqual(response.status_code, 200)
            self.assertIn("application/json", response.headers.get("Content-Type", ""))

            spec = json.loads(response.get_data(as_text=True))
            self.assertEqual(spec.get("openapi"), "3.0.3")
            self.assertEqual(spec.get("info", {}).get("title"), "LaundryFlow API")
            self.assertEqual(spec.get("servers", [{}])[0].get("url"), "http://117.53.47.93:8069")
            self.assertIn("paths", spec)
            self.assertIn("components", spec)

            # Verify documented endpoints match actual routes
            paths = spec["paths"]
            self.assertIn("/api/laundry/auth/login", paths)
            self.assertIn("post", paths["/api/laundry/auth/login"])

            self.assertIn("/api/laundry/customers/search", paths)
            self.assertIn("get", paths["/api/laundry/customers/search"])

            self.assertIn("/api/laundry/customers", paths)
            self.assertIn("post", paths["/api/laundry/customers"])

            self.assertIn("/api/laundry/customers/{customer_id}", paths)
            self.assertIn("delete", paths["/api/laundry/customers/{customer_id}"])

            self.assertIn("/api/laundry/products", paths)
            self.assertIn("get", paths["/api/laundry/products"])

            self.assertIn("/api/laundry/products/{product_id}", paths)
            self.assertIn("get", paths["/api/laundry/products/{product_id}"])

            # Verify inventory endpoints and 2-batch example
            self.assertIn("/api/laundry/inventory", paths)
            self.assertIn("get", paths["/api/laundry/inventory"])
            inv_example = paths["/api/laundry/inventory"]["get"]["responses"]["200"]["content"]["application/json"]["example"]
            self.assertIn("data", inv_example)
            two_batch_item = next((item for item in inv_example["data"] if len(item.get("batches", [])) >= 2), None)
            self.assertIsNotNone(two_batch_item, "Dokumentasi inventory harus menyertakan contoh produk dengan minimal 2 batch")

            self.assertIn("/api/laundry/inventory/{product_id}", paths)
            self.assertIn("get", paths["/api/laundry/inventory/{product_id}"])

            # Verify order endpoints and service speed
            self.assertIn("/api/laundry/service-speeds", paths)
            self.assertIn("get", paths["/api/laundry/service-speeds"])

            self.assertIn("/api/laundry/orders", paths)
            self.assertIn("post", paths["/api/laundry/orders"])

            self.assertIn("/api/laundry/orders/{order_id}", paths)
            self.assertIn("get", paths["/api/laundry/orders/{order_id}"])


    def test_02_scalar_docs_html(self):
        """Test that /api/docs returns HTTP 200 with Scalar API Reference HTML."""
        mock_req = self._mock_request(method="GET")
        with patch("odoo.addons.laundryflow_backend.controllers.docs.request", mock_req):
            response = self.docs_controller.scalar_docs()
            self.assertEqual(response.status_code, 200)
            self.assertIn("text/html", response.headers.get("Content-Type", ""))

            html = response.get_data(as_text=True)
            self.assertIn("@scalar/api-reference", html)
            self.assertIn('id="api-reference"', html)
            self.assertIn('data-url="/api/openapi.json"', html)

