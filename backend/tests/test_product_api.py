import json
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from odoo.exceptions import AccessError
from odoo.tests.common import TransactionCase
from ..controllers.product_controller import ProductApiController


class TestProductApi(TransactionCase):
    """
    Automated test suite for LaundryFlow Product / Laundry Service API.
    Covers:
    1. Authentication & authorization (401, 403, Bearer token, X-Session-Id)
    2. Valid product listing with id, name, unit_price (from list_price), and uom (from uom_id.name)
    3. Consistency with Odoo staging laundry services (Cuci Kiloan, Cuci Setrika, Setrika Saja, Selimut)
    4. Dynamic UoM extraction (proving uom is read from Odoo uom_id.name, not hardcoded)
    5. Explicit rejection of invalid/incomplete product data (zero/negative/missing price, missing/empty uom, empty name)
    6. Product detail endpoint (/api/laundry/products/<id>) validation and responses
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.controller = ProductApiController()
        cls.admin_user = cls.env.ref('base.user_admin')
        cls.public_user = cls.env.ref('base.public_user')

        cls.uom_kg = cls.env['uom.uom'].search([('name', '=', 'kg')], limit=1)
        if not cls.uom_kg:
            cls.uom_kg = cls.env['uom.uom'].browse(16)

        cls.uom_pcs = cls.env['uom.uom'].search([('name', '=', 'pcs')], limit=1)
        if not cls.uom_pcs:
            unit_ref = cls.env.ref('uom.product_uom_unit', raise_if_not_found=False) or cls.env['uom.uom'].browse(1)
            cls.uom_pcs = cls.env['uom.uom'].create({
                'name': 'pcs',
                'relative_uom_id': unit_ref.id,
                'relative_factor': 1.0,
                'active': True,
            })

    def _mock_request(self, user=None, headers=None, params=None, method='GET', data=None):
        """Creates a mock odoo.http.request context."""
        mock_req = MagicMock()
        mock_req.httprequest.method = method
        mock_req.httprequest.headers = headers or {}
        mock_req.params = params or {}
        mock_req.session = MagicMock()
        mock_req.session.uid = user.id if user else None
        mock_req.session.sid = 'mock_session_id_product_test'
        mock_req.db = self.env.cr.dbname
        mock_req.env = self.env(user=user) if user else self.env(user=self.public_user)

        if data is not None:
            if isinstance(data, (dict, list)):
                mock_req.httprequest.data = json.dumps(data).encode('utf-8')
            elif isinstance(data, str):
                mock_req.httprequest.data = data.encode('utf-8')
            elif isinstance(data, bytes):
                mock_req.httprequest.data = data
        else:
            mock_req.httprequest.data = b''

        return mock_req

    def test_01_product_list_unauthorized(self):
        """Unauthenticated request must return 401 Unauthorized."""
        mock_req = self._mock_request(user=None)
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            response = self.controller.get_products()
            self.assertEqual(response.status_code, 401)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))
            self.assertIn('Autentikasi diperlukan', data.get('message', ''))

    def test_02_product_list_public_user_unauthorized(self):
        """Request from public user must return 401 Unauthorized."""
        mock_req = self._mock_request(user=self.public_user)
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            response = self.controller.get_products()
            self.assertEqual(response.status_code, 401)
            data = json.loads(response.get_data(as_text=True))
            self.assertFalse(data.get('success'))

    def test_03_product_list_forbidden(self):
        """User lacking read permissions on product.template must receive 403 Forbidden."""
        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            with patch.object(type(self.env['product.template']), 'check_access', side_effect=AccessError('Permission Denied')):
                response = self.controller.get_products()
                self.assertEqual(response.status_code, 403)
                data = json.loads(response.get_data(as_text=True))
                self.assertFalse(data.get('success'))
                self.assertIn('Akses ditolak', data.get('message', ''))

    def test_04_product_list_invalid_limit(self):
        """Invalid limit parameters (<=0 or non-integer) must return 400 Bad Request."""
        mock_req = self._mock_request(user=self.admin_user, params={'limit': '0'})
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            res_zero = self.controller.get_products(limit='0')
            self.assertEqual(res_zero.status_code, 400)
            data = json.loads(res_zero.get_data(as_text=True))
            self.assertFalse(data.get('success'))

        mock_req_str = self._mock_request(user=self.admin_user, params={'limit': 'abc'})
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req_str):
            res_str = self.controller.get_products(limit='abc')
            self.assertEqual(res_str.status_code, 400)
            data = json.loads(res_str.get_data(as_text=True))
            self.assertFalse(data.get('success'))

    def test_05_product_list_empty_result(self):
        """When no products match the query or no active laundry services exist, must return HTTP 200 with data=[]."""
        mock_req = self._mock_request(user=self.admin_user, params={'q': 'NON_EXISTENT_PRODUCT_XYZ_999'})
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            response = self.controller.get_products(q='NON_EXISTENT_PRODUCT_XYZ_999')
            self.assertEqual(response.status_code, 200)
            data = json.loads(response.get_data(as_text=True))
            self.assertTrue(data.get('success'))
            self.assertEqual(data.get('count'), 0)
            self.assertEqual(data.get('data'), [])

        # Also verify when no active service products exist at all (without query filter)
        active_services = self.env['product.template'].search([
            ('active', '=', True),
            ('type', '=', 'service'),
            ('sale_ok', '=', True),
        ])
        active_services.write({'active': False})
        try:
            mock_req_all_empty = self._mock_request(user=self.admin_user)
            with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req_all_empty):
                res_empty = self.controller.get_products()
                self.assertEqual(res_empty.status_code, 200)
                body_empty = json.loads(res_empty.get_data(as_text=True))
                self.assertTrue(body_empty.get('success'))
                self.assertEqual(body_empty.get('count'), 0)
                self.assertEqual(body_empty.get('data'), [])
        finally:
            active_services.write({'active': True})

    def test_06_staging_laundry_services_price_and_uom_consistency(self):
        """Verify staging laundry services return exact id, name, unit_price, and uom from Odoo."""
        expected = {
            'Cuci Kiloan': {'unit_price': 8000, 'uom': 'kg'},
            'Cuci Setrika': {'unit_price': 10000, 'uom': 'kg'},
            'Setrika Saja': {'unit_price': 6000, 'uom': 'kg'},
            'Selimut': {'unit_price': 25000, 'uom': 'pcs'},
        }
        # Ensure the 4 services exist in the test transaction
        for svc_name, spec in expected.items():
            existing = self.env['product.template'].search([('name', '=', svc_name)], limit=1)
            uom_rec = self.uom_kg if spec['uom'] == 'kg' else self.uom_pcs
            if not existing:
                self.env['product.template'].create({
                    'name': svc_name,
                    'list_price': spec['unit_price'],
                    'uom_id': uom_rec.id,
                    'type': 'service',
                    'active': True,
                })

        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            response = self.controller.get_products()
            self.assertEqual(response.status_code, 200)
            result = json.loads(response.get_data(as_text=True))
            self.assertTrue(result.get('success'))
            by_name = {item['name']: item for item in result.get('data', [])}

            for svc_name, spec in expected.items():
                self.assertIn(svc_name, by_name)
                item = by_name[svc_name]
                self.assertIsInstance(item.get('id'), int)
                self.assertGreater(item['id'], 0)
                self.assertEqual(item.get('name'), svc_name)
                self.assertEqual(item.get('unit_price'), spec['unit_price'])
                self.assertEqual(item.get('uom'), spec['uom'])

    def test_07_dynamic_uom_and_list_price_from_odoo_orm(self):
        """Verify unit_price and uom come dynamically from Odoo list_price and uom_id.name (not hardcoded)."""
        custom_uom = self.env['uom.uom'].create({
            'name': 'pasang',
            'relative_uom_id': 1,
            'relative_factor': 1.0,
            'active': True,
        })
        custom_prod = self.env['product.template'].create({
            'name': 'Cuci Sepatu Khusus Test',
            'list_price': 35000.0,
            'uom_id': custom_uom.id,
            'type': 'service',
            'active': True,
        })

        mock_req = self._mock_request(user=self.admin_user, params={'q': 'Cuci Sepatu Khusus Test'})
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            response = self.controller.get_products(q='Cuci Sepatu Khusus Test')
            self.assertEqual(response.status_code, 200)
            result = json.loads(response.get_data(as_text=True))
            self.assertEqual(result.get('count'), 1)
            item = result['data'][0]
            self.assertEqual(item['id'], custom_prod.id)
            self.assertEqual(item['name'], 'Cuci Sepatu Khusus Test')
            self.assertEqual(item['unit_price'], 35000)
            self.assertEqual(item['uom'], 'pasang')

    def test_08_invalid_or_incomplete_product_price_rejected_explicitly(self):
        """Products with 0, negative, or missing list_price must be rejected explicitly (422), never filled with defaults."""
        zero_price_prod = self.env['product.template'].create({
            'name': 'Produk Harga Nol Invalid Test',
            'list_price': 0.0,
            'uom_id': self.uom_kg.id,
            'type': 'service',
            'active': True,
        })

        mock_req = self._mock_request(user=self.admin_user, params={'q': 'Produk Harga Nol Invalid Test'})
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            res_zero = self.controller.get_products(q='Produk Harga Nol Invalid Test')
            self.assertEqual(res_zero.status_code, 422)
            body_zero = json.loads(res_zero.get_data(as_text=True))
            self.assertFalse(body_zero.get('success'))
            self.assertIn('list_price', body_zero.get('message', ''))
            self.assertTrue(body_zero.get('invalid_products'))
            self.assertEqual(body_zero['invalid_products'][0]['id'], zero_price_prod.id)

        # Also test negative price via detail endpoint
        zero_price_prod.write({'list_price': -5000.0})
        mock_req_detail = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req_detail):
            res_neg = self.controller.get_product_detail(str(zero_price_prod.id))
            self.assertEqual(res_neg.status_code, 422)
            body_neg = json.loads(res_neg.get_data(as_text=True))
            self.assertFalse(body_neg.get('success'))
            self.assertIn('list_price', body_neg.get('message', ''))

    def test_09_invalid_or_missing_uom_and_name_rejected_explicitly(self):
        """Products with missing/empty UoM or missing name must be rejected explicitly without empty string fallback."""
        # Direct unit test of _validate_and_serialize_product with incomplete record objects & dicts
        missing_uom_record = SimpleNamespace(
            id=991,
            name='Layanan Tanpa Satuan',
            list_price=9000.0,
            uom_id=SimpleNamespace(id=None, name=''),
            type='service',
            active=True,
            currency_id=SimpleNamespace(id=1, name='IDR'),
        )
        is_valid, err_info = self.controller._validate_and_serialize_product(missing_uom_record)
        self.assertFalse(is_valid)
        self.assertIn('uom_id', err_info.get('reason', ''))

        empty_uom_dict = {
            'id': 992,
            'name': 'Layanan UoM Kosong',
            'list_price': 12000.0,
            'uom_id': (16, '   '),
            'type': 'service',
            'active': True,
        }
        is_valid_dict, err_dict = self.controller._validate_and_serialize_product(empty_uom_dict)
        self.assertFalse(is_valid_dict)
        self.assertIn('uom_id', err_dict.get('reason', ''))

        missing_name_dict = {
            'id': 993,
            'name': '   ',
            'list_price': 12000.0,
            'uom_id': (16, 'kg'),
            'type': 'service',
            'active': True,
        }
        is_valid_name, err_name = self.controller._validate_and_serialize_product(missing_name_dict)
        self.assertFalse(is_valid_name)
        self.assertIn('name', err_name.get('reason', ''))

        # Verify endpoint returns 422 when Odoo returns a record with missing uom_id
        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            with patch.object(type(self.env['product.template']), 'search', return_value=[missing_uom_record]):
                response = self.controller.get_products()
                self.assertEqual(response.status_code, 422)
                body = json.loads(response.get_data(as_text=True))
                self.assertFalse(body.get('success'))
                self.assertIn('uom_id', body.get('message', ''))

    def test_10_product_detail_endpoint(self):
        """Test GET /api/laundry/products/<id> for valid product, invalid ID (400), and not found (404)."""
        prod = self.env['product.template'].create({
            'name': 'Bed Cover Besar Test',
            'list_price': 30000.0,
            'uom_id': self.uom_pcs.id,
            'type': 'service',
            'active': True,
        })

        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            # Valid detail
            res_ok = self.controller.get_product_detail(str(prod.id))
            self.assertEqual(res_ok.status_code, 200)
            body_ok = json.loads(res_ok.get_data(as_text=True))
            self.assertTrue(body_ok.get('success'))
            self.assertEqual(body_ok['data']['id'], prod.id)
            self.assertEqual(body_ok['data']['name'], 'Bed Cover Besar Test')
            self.assertEqual(body_ok['data']['unit_price'], 30000)
            self.assertEqual(body_ok['data']['uom'], 'pcs')

            # Invalid ID format
            res_bad = self.controller.get_product_detail('abc')
            self.assertEqual(res_bad.status_code, 400)

            # Non-existent ID
            res_404 = self.controller.get_product_detail('9999999')
            self.assertEqual(res_404.status_code, 404)

    def test_11_inactive_products_excluded_and_bearer_auth(self):
        """Inactive products must be excluded and Bearer token authentication must succeed."""
        inactive_prod = self.env['product.template'].create({
            'name': 'Layanan Nonaktif Arsip Test',
            'list_price': 15000.0,
            'uom_id': self.uom_kg.id,
            'type': 'service',
            'active': False,
        })

        mock_session_store = {
            'valid_bearer_token_product': {'uid': self.admin_user.id},
        }
        mock_req = self._mock_request(
            user=None,
            headers={'Authorization': 'Bearer valid_bearer_token_product'},
            params={'q': 'Layanan Nonaktif Arsip Test'},
        )
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req), \
             patch('odoo.addons.laundryflow_backend.controllers.product_controller.session_store', return_value=mock_session_store):
            res = self.controller.get_products(q='Layanan Nonaktif Arsip Test')
            self.assertEqual(res.status_code, 200)
            res_body = json.loads(res.get_data(as_text=True))
            self.assertTrue(res_body.get('success'))
            self.assertEqual(res_body.get('count'), 0)
            self.assertEqual(res_body.get('data'), [])

            res_detail = self.controller.get_product_detail(str(inactive_prod.id))
            self.assertEqual(res_detail.status_code, 404)
            detail_body = json.loads(res_detail.get_data(as_text=True))
            self.assertFalse(detail_body.get('success'))

    def test_12_backend_filters_only_laundry_services_without_type_param(self):
        """
        Backend must automatically filter for active saleable service products (type='service', sale_ok=True)
        without requiring Flutter to send ?type=service, and must exclude 'consu' or internal non-sale items.
        """
        service_prod = self.env['product.template'].create({
            'name': 'Cuci Express Layanan Valid Test',
            'list_price': 15000.0,
            'uom_id': self.uom_kg.id,
            'type': 'service',
            'active': True,
            'sale_ok': True,
        })
        consu_prod = self.env['product.template'].create({
            'name': 'Deterjen Gudang Barang Fisik Test',
            'list_price': 45000.0,
            'uom_id': self.uom_pcs.id,
            'type': 'consu',
            'active': True,
            'sale_ok': True,
        })
        internal_service = self.env['product.template'].create({
            'name': 'Servis Mesin Internal Non-Sale Test',
            'list_price': 100000.0,
            'uom_id': self.uom_pcs.id,
            'type': 'service',
            'active': True,
            'sale_ok': False,
        })

        mock_req = self._mock_request(user=self.admin_user)
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req):
            # Call without ?type=... parameter (default Flutter call)
            response = self.controller.get_products()
            self.assertEqual(response.status_code, 200)
            result = json.loads(response.get_data(as_text=True))
            self.assertTrue(result.get('success'))

            returned_ids = [item['id'] for item in result.get('data', [])]
            self.assertIn(service_prod.id, returned_ids)
            self.assertNotIn(consu_prod.id, returned_ids)
            self.assertNotIn(internal_service.id, returned_ids)

            for item in result.get('data', []):
                self.assertEqual(item.get('type'), 'service')

            # Detail endpoint must also exclude non-service and non-saleable products
            res_consu_detail = self.controller.get_product_detail(str(consu_prod.id))
            self.assertEqual(res_consu_detail.status_code, 404)

            res_internal_detail = self.controller.get_product_detail(str(internal_service.id))
            self.assertEqual(res_internal_detail.status_code, 404)

    def test_13_non_service_type_query_param_rejected(self):
        """Passing ?type=consu must be rejected with 400 Bad Request, while ?type=service or no type succeeds."""
        self.env['product.template'].create({
            'name': 'Cuci Karpet Layanan Test',
            'list_price': 20000.0,
            'uom_id': self.uom_pcs.id,
            'type': 'service',
            'active': True,
            'sale_ok': True,
        })

        mock_req_consu = self._mock_request(user=self.admin_user, params={'type': 'consu'})
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req_consu):
            res_consu = self.controller.get_products(type='consu')
            self.assertEqual(res_consu.status_code, 400)
            body_consu = json.loads(res_consu.get_data(as_text=True))
            self.assertFalse(body_consu.get('success'))

        mock_req_service = self._mock_request(user=self.admin_user, params={'type': 'service'})
        with patch('odoo.addons.laundryflow_backend.controllers.product_controller.request', mock_req_service):
            res_service = self.controller.get_products(type='service')
            self.assertEqual(res_service.status_code, 200)
            body_service = json.loads(res_service.get_data(as_text=True))
            self.assertTrue(body_service.get('success'))


