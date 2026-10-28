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
        mock_req.httprequest.method = method
        mock_req.httprequest.headers = headers or {}
        mock_req.httprequest.data = data if data is not None else b''
        mock_req.params = params or {}
        mock_req.session = MagicMock()
        if user and not user._is_public():
            mock_req.session.uid = user.id
            mock_req.env = self.env(user=user)
        else:
            mock_req.session.uid = False
            mock_req.env = self.env(user=self.public_user)

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
        """Test search query with no matching customer returns 404 and success=False."""
        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.search_customers(q="XYZ_NON_EXISTENT_NAME_99999")
            self.assertEqual(response.status_code, 404)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))
            self.assertIn("tidak ditemukan", data.get('message', '').lower())
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
        """Test creating customer with valid data persists via Odoo ORM and returns safe partner data."""
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

            # Verify safe fields only (no internal / sensitive data leakage)
            allowed_fields = {'id', 'name', 'phone', 'email', 'street', 'city', 'address'}
            self.assertTrue(allowed_fields.issuperset(customer.keys()))
            self.assertNotIn('password', customer)
            self.assertNotIn('credit', customer)
            self.assertNotIn('comment', customer)
            self.assertNotIn('invoice_ids', customer)

            # Verify record persistence in res.partner via Odoo ORM
            partner_rec = self.env['res.partner'].browse(customer['id'])
            self.assertTrue(partner_rec.exists())
            self.assertEqual(partner_rec.name, 'Test Pelanggan')
            self.assertEqual(partner_rec.phone, '08551234567')
            self.assertEqual(partner_rec.email, 'pelanggan@test.com')
            self.assertEqual(partner_rec.street, 'Jl. Kenanga No. 5')
            self.assertEqual(partner_rec.city, 'Surabaya')
            self.assertTrue(partner_rec.active)
            self.assertFalse(partner_rec.is_company)

    def test_13_create_customer_empty_or_whitespace_name(self):
        """Test creating customer with empty, whitespace-only, or numeric name returns 400."""
        for invalid_name in ['', '   ', '\t\n', '989', '12345', 'Budi 123', '@@@']:
            payload = json.dumps({'name': invalid_name, 'phone': '08123456789'}).encode('utf-8')
            mock_req = self._mock_request(user=self.admin_user, method='POST', data=payload)
            with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
                response = self.controller.create_customer()
                self.assertEqual(response.status_code, 400, f"Expected 400 for invalid name: {invalid_name}")
                data = json.loads(response.get_data(as_text=True))
                self.assertIs(data.get('success'), False)
                self.assertIn('name', data.get('message', ''))

    def test_14_create_customer_empty_or_whitespace_phone(self):
        """Test creating customer with empty or whitespace-only phone returns 400."""
        for invalid_phone in ['', '   ', '\t\n']:
            payload = json.dumps({'name': 'Budi Santoso', 'phone': invalid_phone}).encode('utf-8')
            mock_req = self._mock_request(user=self.admin_user, method='POST', data=payload)
            with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
                response = self.controller.create_customer()
                self.assertEqual(response.status_code, 400)
                data = json.loads(response.get_data(as_text=True))
                self.assertIs(data.get('success'), False)
                self.assertIn('phone', data.get('message', ''))

    def test_15_create_customer_invalid_data_types(self):
        """Test creating customer with non-string data types for name, phone, and optional fields returns 400."""
        invalid_payloads = [
            {'name': 12345, 'phone': '08123456789'},
            {'name': ['Budi'], 'phone': '08123456789'},
            {'name': True, 'phone': '08123456789'},
            {'name': 'Budi Santoso', 'phone': 8123456789},
            {'name': 'Budi Santoso', 'phone': ['08123456789']},
            {'name': 'Budi Santoso', 'phone': True},
            {'name': 'Budi Santoso', 'phone': {'number': '08123456789'}},
            {'name': 'Budi Santoso', 'phone': '08123456789', 'street': 123},
            {'name': 'Budi Santoso', 'phone': '08123456789', 'email': ['a@b.com']},
            {'name': 'Budi Santoso', 'phone': '08123456789', 'city': {'name': 'Jakarta'}},
        ]
        for body in invalid_payloads:
            payload = json.dumps(body).encode('utf-8')
            mock_req = self._mock_request(user=self.admin_user, method='POST', data=payload)
            with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
                response = self.controller.create_customer()
                self.assertEqual(response.status_code, 400, f"Expected 400 for payload: {body}")
                data = json.loads(response.get_data(as_text=True))
                self.assertIs(data.get('success'), False)
                self.assertTrue(isinstance(data.get('message'), str) and len(data['message']) > 0)

    def test_16_create_customer_invalid_phone_formats(self):
        """Test creating customer with invalid phone number formats returns 400."""
        invalid_phones = [
            'abc',
            '0812abc3456',
            '12345',                     # too short (< 8 digits)
            '0812345',                   # too short (7 digits)
            '081234567890123456',        # too long (> 15 digits)
            '+08123456789',              # invalid international country code starting with 0
            '++628123456789',            # double plus
            '62+8123456789',             # plus in middle
            '+62 (812 3456-7890',        # unbalanced parentheses
            '+62 () 8123456789',         # empty parentheses
            '0812@3456#789',             # invalid symbols
            '0000000000',                # all zeros
            '90890809',                  # missing valid prefix (0, 62, or +)
            '1234567890',                # missing valid prefix
        ]
        for bad_phone in invalid_phones:
            payload = json.dumps({'name': 'Budi Santoso', 'phone': bad_phone}).encode('utf-8')
            mock_req = self._mock_request(user=self.admin_user, method='POST', data=payload)
            with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
                response = self.controller.create_customer()
                self.assertEqual(response.status_code, 400, f"Expected 400 for invalid phone: {bad_phone}")
                data = json.loads(response.get_data(as_text=True))
                self.assertIs(data.get('success'), False)
                self.assertTrue(isinstance(data.get('message'), str) and len(data['message']) > 0)

    def test_17_create_customer_valid_international_phone_formats(self):
        """Test creating customer with valid international and local phone formats returns 201."""
        valid_phones = [
            '+6281234567890',
            '+62 812-3456-7890',
            '6281234567890',
            '+1 (415) 555-2671',
            '+44 20 7946 0958',
            '+65 9123 4567',
        ]
        for valid_phone in valid_phones:
            payload = json.dumps({
                'name': 'Pelanggan Internasional',
                'phone': valid_phone,
            }).encode('utf-8')
            mock_req = self._mock_request(user=self.admin_user, method='POST', data=payload)
            with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
                response = self.controller.create_customer()
                self.assertEqual(response.status_code, 201, f"Expected 201 for valid phone: {valid_phone}")
                data = json.loads(response.get_data(as_text=True))
                self.assertIs(data.get('success'), True)
                self.assertEqual(data.get('data', {}).get('phone'), valid_phone)

    def test_18_delete_customer_unauthorized(self):
        """Test that unauthenticated request to delete customer returns 401."""
        mock_req = self._mock_request(user=None, method='DELETE')
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.delete_customer(customer_id="1")
            self.assertEqual(response.status_code, 401)
            data = json.loads(response.get_data(as_text=True))
            self.assertIs(data.get('success'), False)

    def test_19_delete_customer_invalid_or_not_found(self):
        """Test deleting customer with invalid ID returns 400 and non-existent ID returns 404."""
        for bad_id in ["abc", "-5", "0"]:
            mock_req = self._mock_request(user=self.admin_user, method='DELETE')
            with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
                response = self.controller.delete_customer(customer_id=bad_id)
                self.assertEqual(response.status_code, 400)
                data = json.loads(response.get_data(as_text=True))
                self.assertIs(data.get('success'), False)

        mock_req = self._mock_request(user=self.admin_user, method='DELETE')
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.delete_customer(customer_id="99999999")
            self.assertEqual(response.status_code, 404)
            data = json.loads(response.get_data(as_text=True))
            self.assertIs(data.get('success'), False)
            self.assertIn("tidak ditemukan", data.get('message', '').lower())

    def test_20_delete_customer_success(self):
        """Test creating and then deleting a customer returns 200 and removes customer."""
        payload = json.dumps({
            'name': 'Pelanggan Hapus',
            'phone': '081299887766',
        }).encode('utf-8')
        mock_req_create = self._mock_request(user=self.admin_user, method='POST', data=payload)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req_create):
            create_resp = self.controller.create_customer()
            self.assertEqual(create_resp.status_code, 201)
            created_id = json.loads(create_resp.get_data(as_text=True))['data']['id']

        mock_req_del = self._mock_request(user=self.admin_user, method='DELETE')
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req_del):
            del_resp = self.controller.delete_customer(customer_id=str(created_id))
            self.assertEqual(del_resp.status_code, 200)
            del_data = json.loads(del_resp.get_data(as_text=True))
            self.assertIs(del_data.get('success'), True)
            self.assertEqual(del_data.get('data', {}).get('id'), created_id)

    def test_21_create_customer_minimal_valid_data_orm_persistence(self):
        """Test creating customer with minimal required fields (name & phone) saves via ORM and returns safe fields."""
        payload = json.dumps({
            'name': '  Siti Aminah  ',
            'phone': '  +6281398765432  ',
        }).encode('utf-8')
        mock_req = self._mock_request(user=self.admin_user, method='POST', data=payload)
        with patch('odoo.addons.laundryflow_backend.controllers.main.request', mock_req):
            response = self.controller.create_customer()
            self.assertEqual(response.status_code, 201)
            body = json.loads(response.get_data(as_text=True))
            self.assertIs(body.get('success'), True)

            customer = body.get('data', {})
            self.assertIsInstance(customer.get('id'), int)
            self.assertEqual(customer.get('name'), 'Siti Aminah')
            self.assertEqual(customer.get('phone'), '+6281398765432')

            partner_rec = self.env['res.partner'].browse(customer['id'])
            self.assertTrue(partner_rec.exists())
            self.assertEqual(partner_rec.name, 'Siti Aminah')
            self.assertEqual(partner_rec.phone, '+6281398765432')
