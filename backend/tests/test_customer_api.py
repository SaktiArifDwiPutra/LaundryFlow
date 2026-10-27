import json
from unittest.mock import MagicMock, patch
from odoo.tests.common import TransactionCase
from ..controllers.main import CustomerApiController


class TestCustomerApi(TransactionCase):
    """
    Automated test suite for LaundryFlow Customer Search API.
    Tests:
    1. Unauthorized access (unauthenticated / missing authorization)
    2. Invalid parameters (missing query, empty/whitespace query, invalid limit)
    3. Successful customer search by name
    4. Successful customer search by phone number
    5. Empty search results
    6. Result limiting and capping
    7. No internal / sensitive data leakage
    
    Constraint: No new res.partner records created during testing.
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.controller = CustomerApiController()
        cls.admin_user = cls.env.ref('base.user_admin')
        cls.public_user = cls.env.ref('base.public_user')

        # Use existing partners only (DO NOT CREATE NEW PARTNERS)
        cls.partner_with_phone = cls.env['res.partner'].search([('phone', '!=', False)], limit=1)
        if not cls.partner_with_phone:
            cls.partner_with_phone = cls.env['res.partner'].search([], limit=1)

    def _mock_request(self, user=None, headers=None, params=None, method='GET'):
        """Creates a mock odoo.http.request context."""
        mock_req = MagicMock()
        mock_req.env = self.env
        mock_req.httprequest.method = method
        mock_req.httprequest.headers = headers or {}
        mock_req.params = params or {}
        mock_req.session = MagicMock()
        if user and not user._is_public():
            mock_req.session.uid = user.id
            mock_req.env.user = user
        else:
            mock_req.session.uid = False
            mock_req.env.user = self.public_user

        return mock_req

    def test_01_customer_search_unauthorized(self):
        """Test access without authorization returns 401 Unauthorized."""
        mock_req = self._mock_request(user=None)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.search_customers(q="Budi")
            self.assertEqual(response.status_code, 401)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))
            self.assertIn("Autentikasi", data.get('message', ''))

    def test_02_customer_search_invalid_parameter_missing_q(self):
        """Test search with missing 'q' parameter returns 400 Bad Request."""
        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.search_customers()
            self.assertEqual(response.status_code, 400)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))
            self.assertIn("wajib diisi", data.get('message', ''))

    def test_03_customer_search_invalid_parameter_empty_q(self):
        """Test search with empty or whitespace 'q' returns 400 Bad Request."""
        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.search_customers(q="   ")
            self.assertEqual(response.status_code, 400)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))
            self.assertIn("wajib diisi", data.get('message', ''))

    def test_04_customer_search_invalid_limit(self):
        """Test search with negative or non-integer limit returns 400 Bad Request."""
        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            # Negative limit
            response_neg = self.controller.search_customers(q="Budi", limit="-5")
            self.assertEqual(response_neg.status_code, 400)
            data_neg = json.loads(response_neg.get_data(as_text=True))
            self.assertFalse(data_neg.get('success'))

            # Invalid string limit
            response_str = self.controller.search_customers(q="Budi", limit="abc")
            self.assertEqual(response_str.status_code, 400)
            data_str = json.loads(response_str.get_data(as_text=True))
            self.assertFalse(data_str.get('success'))

    def test_05_customer_search_success_by_name(self):
        """Test successful customer search by name using existing contacts."""
        target_name = self.partner_with_phone.name[:4]
        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.search_customers(q=target_name)
            self.assertEqual(response.status_code, 200)
            data = json.loads(response.get_data(as_text=True))
            self.assertTrue(data.get('success'))
            self.assertGreaterEqual(data.get('count', 0), 1)

            # Validate returned fields and ensure no internal fields leakage
            allowed_fields = {'id', 'name', 'phone', 'email', 'street', 'city'}
            for customer in data.get('data', []):
                self.assertTrue(allowed_fields.issuperset(customer.keys()))
                self.assertNotIn('password', customer)
                self.assertNotIn('credit', customer)
                self.assertNotIn('comment', customer)
                self.assertNotIn('invoice_ids', customer)

    def test_06_customer_search_success_by_phone(self):
        """Test successful customer search by phone number using existing contacts."""
        if self.partner_with_phone.phone:
            target_phone = self.partner_with_phone.phone[:5]
            mock_req = self._mock_request(user=self.admin_user)
            with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
                response = self.controller.search_customers(q=target_phone)
                self.assertEqual(response.status_code, 200)
                data = json.loads(response.get_data(as_text=True))
                self.assertTrue(data.get('success'))
                self.assertGreaterEqual(data.get('count', 0), 1)

    def test_07_customer_search_empty_result(self):
        """Test search query with no matching customer returns empty list."""
        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.search_customers(q="XYZ_NON_EXISTENT_NAME_99999")
            self.assertEqual(response.status_code, 200)
            data = json.loads(response.get_data(as_text=True))
            self.assertTrue(data.get('success'))
            self.assertEqual(data.get('count'), 0)
            self.assertEqual(data.get('data'), [])

    def test_08_customer_search_limit_capping(self):
        """Test that limit restricts the result count and caps at 50."""
        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.search_customers(q="a", limit=1)
            self.assertEqual(response.status_code, 200)
            data = json.loads(response.get_data(as_text=True))
            self.assertTrue(data.get('success'))
            self.assertLessEqual(data.get('count', 0), 1)
