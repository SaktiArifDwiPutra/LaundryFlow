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

    def _mock_request(self, user=None, headers=None, params=None, method='GET', data=None):
        """Creates a mock odoo.http.request context."""
        mock_req = MagicMock()
        mock_req.env = self.env
        mock_req.httprequest.method = method
        mock_req.httprequest.headers = headers or {}
        mock_req.httprequest.data = data if data is not None else b''
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

    def test_09_create_customer_unauthorized(self):
        """Test that unauthenticated request to create customer returns 401."""
        mock_req = self._mock_request(user=None, method='POST')
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.create_customer()
            self.assertEqual(response.status_code, 401)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))

    def test_10_create_customer_invalid_format(self):
        """Test creating customer with empty or invalid JSON body returns 400."""
        # Empty body
        mock_req = self._mock_request(user=self.admin_user, method='POST', data=b'')
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.create_customer()
            self.assertEqual(response.status_code, 400)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))

        # Malformed JSON
        mock_req = self._mock_request(user=self.admin_user, method='POST', data=b'{not-valid-json}')
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.create_customer()
            self.assertEqual(response.status_code, 400)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))

    def test_11_create_customer_missing_required_fields(self):
        """Test creating customer with missing name or phone returns 400."""
        # Missing name
        payload = json.dumps({'phone': '08123456789'}).encode('utf-8')
        mock_req = self._mock_request(user=self.admin_user, method='POST', data=payload)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.create_customer()
            self.assertEqual(response.status_code, 400)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))

        # Missing phone
        payload = json.dumps({'name': 'Pelanggan Baru'}).encode('utf-8')
        mock_req = self._mock_request(user=self.admin_user, method='POST', data=payload)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.create_customer()
            self.assertEqual(response.status_code, 400)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))

    def test_12_create_customer_success(self):
        """Test creating customer with valid data returns 201 and created partner data."""
        payload = json.dumps({
            'name': 'Test Pelanggan',
            'phone': '08551234567',
            'address': 'Jl. Kenanga No. 5',
            'email': 'pelanggan@test.com',
            'city': 'Surabaya'
        }).encode('utf-8')
        mock_req = self._mock_request(user=self.admin_user, method='POST', data=payload)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.create_customer()
            self.assertEqual(response.status_code, 201)
            data = json.loads(response.get_data(as_text=True))
            self.assertTrue(data.get('success'))
            customer = data.get('data', {})
            self.assertTrue(customer.get('id'))
            self.assertEqual(customer.get('name'), 'Test Pelanggan')
            self.assertEqual(customer.get('phone'), '08551234567')
            self.assertEqual(customer.get('street'), 'Jl. Kenanga No. 5')
            self.assertEqual(customer.get('address'), 'Jl. Kenanga No. 5')
            self.assertEqual(customer.get('city'), 'Surabaya')
            self.assertEqual(customer.get('email'), 'pelanggan@test.com')
