import json
import logging
import re
from odoo import http
from odoo.http import request, Response
from odoo.http.session import session_store, authenticate, save_session
from odoo.exceptions import AccessError

_logger = logging.getLogger(__name__)


class CustomerApiController(http.Controller):

    def _json_response(self, data, status=200):
        """Helper to format JSON responses with CORS headers."""
        headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With, X-Session-Id, X-Api-Key',
        }
        return Response(
            json.dumps(data),
            status=status,
            headers=headers
        )

    def _get_authenticated_user(self):
        """
        Validates authentication and returns the active res.users record.
        Returns None if request is unauthenticated or belongs to a public user.
        Supports:
        - Active Odoo HTTP session (request.session.uid)
        - Header 'Authorization: Bearer <session_id>'
        - Header 'Authorization: Token <session_id>'
        - Header 'X-Session-Id: <session_id>'
        - Header 'X-Api-Key: <api_key>'
        - Query parameters 'session_id' or 'api_key'
        """
        # 1. Check standard active session
        uid = getattr(request.session, 'uid', None)
        if uid:
            user = request.env['res.users'].sudo().browse(uid)
            if user.exists() and not user._is_public():
                return user

        # 2. Extract token from headers or query parameters
        auth_header = request.httprequest.headers.get('Authorization') or ''
        token = None
        if auth_header.startswith('Bearer '):
            token = auth_header.split(' ', 1)[1].strip()
        elif auth_header.startswith('Token '):
            token = auth_header.split(' ', 1)[1].strip()

        if not token:
            token = (
                request.httprequest.headers.get('X-Session-Id')
                or request.httprequest.headers.get('X-Api-Key')
                or request.params.get('session_id')
                or request.params.get('api_key')
            )

        if token:
            # 2a. Lookup in session store
            try:
                store = session_store()
                session = store.get(token)
                if session and session.get('uid'):
                    user = request.env['res.users'].sudo().browse(session.get('uid'))
                    if user.exists() and not user._is_public():
                        return user
            except Exception as e:
                _logger.debug("Session lookup failed: %s", e)

            # 2b. Lookup via res.users.apikeys if applicable
            try:
                if 'res.users.apikeys' in request.env:
                    key_uid = request.env['res.users.apikeys'].sudo()._check_credentials(scope='rpc', key=token)
                    if key_uid:
                        user = request.env['res.users'].sudo().browse(key_uid)
                        if user.exists() and not user._is_public():
                            return user
            except Exception as e:
                _logger.debug("API key lookup failed: %s", e)

        # 3. Request env user fallback if valid and non-public
        if hasattr(request, 'env') and request.env.user and not request.env.user._is_public():
            return request.env.user

        return None

    # Endpoint Login untuk kemudahan autentikasi client API
    @http.route(['/api/laundry/auth/login', '/api/auth/login'], type='http', auth='none', methods=['POST', 'OPTIONS'], csrf=False)
    def login(self, **kwargs):
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            body = json.loads(request.httprequest.data.decode('utf-8'))
            db = body.get('db') or getattr(request, 'db', None) or 'odoo20'
            login_user = body.get('login') or body.get('username')
            password = body.get('password')

            if not login_user or not password:
                return self._json_response({
                    'success': False,
                    'message': 'Username dan password wajib diisi'
                }, status=400)

            credential = {'login': login_user, 'password': password, 'type': 'password'}
            auth_info = authenticate(request.session, request.env, credential)
            uid = auth_info.get('uid')
            if not uid:
                return self._json_response({
                    'success': False,
                    'message': 'Username atau password salah'
                }, status=401)

            request.session.db = db
            save_session(request, request.env)
            user = request.env['res.users'].sudo().browse(uid)

            return self._json_response({
                'success': True,
                'message': 'Login berhasil',
                'data': {
                    'uid': uid,
                    'name': user.name,
                    'username': user.login,
                    'session_id': request.session.sid,
                }
            })
        except Exception as e:
            _logger.exception("Login error: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Autentikasi gagal'
            }, status=401)

    # Endpoint Pencarian Pelanggan LaundryFlow
    @http.route(
        ['/api/laundry/customers/search', '/api/customers/search'],
        type='http',
        auth='public',
        methods=['GET', 'OPTIONS'],
        csrf=False
    )
    def search_customers(self, **kwargs):
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            # 1. Autentikasi Pengguna
            user = self._get_authenticated_user()
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.'
                }, status=401)

            # 2. Hak Akses (Authorization)
            try:
                request.env['res.partner'].with_user(user).check_access('read')
            except AccessError:
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Anda tidak memiliki izin untuk melihat data pelanggan.'
                }, status=403)

            # 3. Validasi Parameter Pencarian 'q'
            q = kwargs.get('q') or request.params.get('q')
            if not q:
                q = kwargs.get('query') or request.params.get('query')

            if not q or not isinstance(q, str) or not q.strip():
                return self._json_response({
                    'success': False,
                    'message': 'Parameter pencarian (q) wajib diisi'
                }, status=400)

            q = q.strip()

            # 4. Validasi Parameter Limit
            limit_raw = kwargs.get('limit') or request.params.get('limit')
            limit = 20
            if limit_raw is not None and str(limit_raw).strip() != '':
                try:
                    limit = int(limit_raw)
                    if limit <= 0:
                        return self._json_response({
                            'success': False,
                            'message': 'Parameter limit harus lebih besar dari 0'
                        }, status=400)
                    if limit > 50:
                        limit = 50
                except (ValueError, TypeError):
                    return self._json_response({
                        'success': False,
                        'message': 'Parameter limit harus berupa angka yang valid'
                    }, status=400)

            # 5. Domain Pencarian (berdasarkan Nama atau Nomor Telepon)
            domain = [
                ('active', '=', True),
                '|',
                ('name', 'ilike', q),
                ('phone', 'ilike', q),
            ]

            # 6. Ambil data dengan membatasi field ke data kontak pelanggan saja
            # Tidak mengembalikan data internal (e.g. password, invoice_ids, bank_ids, credit, comment)
            fields = ['id', 'name', 'phone', 'email', 'street', 'city']
            partners = request.env['res.partner'].with_user(user).search_read(
                domain=domain,
                fields=fields,
                limit=limit,
                order='name asc'
            )

            # 7. Format data hasil respon
            data = [
                {
                    'id': p['id'],
                    'name': p.get('name') or '',
                    'phone': p.get('phone') or '',
                    'email': p.get('email') or '',
                    'street': p.get('street') or '',
                    'city': p.get('city') or '',
                }
                for p in partners
            ]

            if not data:
                return self._json_response({
                    'success': False,
                    'message': 'Data pelanggan tidak ditemukan',
                    'count': 0,
                    'data': []
                }, status=404)

            return self._json_response({
                'success': True,
                'count': len(data),
                'data': data
            })

        except Exception as e:
            _logger.exception("Error searching customers: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan internal pada server'
            }, status=500)

    def _validate_name(self, name):
        """
        Validates customer name data type and format.
        Must be a non-empty string containing valid alphabetic characters (no numbers).
        Returns tuple (is_valid, cleaned_name_or_error_message).
        """
        if name is None:
            return False, 'Field name wajib diisi'
        if not isinstance(name, str):
            return False, 'Field name harus berupa string yang valid'

        cleaned = name.strip()
        if not cleaned:
            return False, 'Field name wajib diisi dan tidak boleh hanya berisi spasi'

        if re.search(r'\d', cleaned):
            return False, 'Field name tidak boleh mengandung angka'

        if not re.fullmatch(r"^[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ\s\.\'\-]*$", cleaned):
            return False, 'Field name hanya boleh berisi huruf dan karakter nama yang valid'

        return True, cleaned

    def _validate_phone(self, phone):
        """
        Validates phone number data type and format.
        Supports local formats (e.g. 08123456789, 021-5551234) and valid international
        formats (e.g. +628123456789, +62 812-3456-7890, 628123456789, +1 (415) 555-2671, +6591234567).
        Returns tuple (is_valid, cleaned_phone_or_error_message).
        """
        if phone is None:
            return False, 'Field phone wajib diisi'
        if not isinstance(phone, str):
            return False, 'Field phone harus berupa string yang valid'

        cleaned = phone.strip()
        if not cleaned:
            return False, 'Field phone wajib diisi dan tidak boleh kosong'

        if not re.fullmatch(r'^\+?[0-9][0-9\s\-\(\)]*[0-9]$', cleaned):
            return False, 'Format nomor telepon tidak valid'

        if cleaned.count('(') != cleaned.count(')') or '()' in cleaned:
            return False, 'Format nomor telepon tidak valid'

        digits = re.sub(r'\D', '', cleaned)
        if len(digits) < 9 or len(digits) > 15:
            return False, 'Nomor telepon harus terdiri dari 9 hingga 15 digit angka'

        if set(digits) == {'0'}:
            return False, 'Format nomor telepon tidak valid'

        if cleaned.startswith('+'):
            rest = cleaned[1:].lstrip()
            if not rest or rest[0] == '0':
                return False, 'Format nomor telepon internasional tidak valid'
        elif cleaned.startswith('0'):
            if len(digits) < 9 or digits[1] == '0':
                return False, 'Format nomor telepon lokal tidak valid'
        elif cleaned.startswith('62'):
            if len(digits) < 10 or digits[2] == '0':
                return False, 'Format nomor telepon tidak valid'
        else:
            return False, 'Nomor telepon harus diawali dengan 0, 62, atau kode negara internasional (+)'

        return True, cleaned

    # Endpoint Penambahan Pelanggan Baru LaundryFlow
    @http.route(
        ['/api/laundry/customers', '/api/customers', '/api/laundry/customers/create', '/api/customers/create'],
        type='http',
        auth='public',
        methods=['POST', 'OPTIONS'],
        csrf=False
    )
    def create_customer(self, **kwargs):
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            # 1. Autentikasi Pengguna
            user = self._get_authenticated_user()
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.'
                }, status=401)

            # 2. Hak Akses (Authorization)
            try:
                request.env['res.partner'].with_user(user).check_access('create')
            except AccessError:
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Anda tidak memiliki izin untuk membuat data pelanggan.'
                }, status=403)

            # 3. Pemeriksaan awal format request (Request Validation)
            raw_data = request.httprequest.data
            body = None
            if raw_data:
                try:
                    body = json.loads(raw_data.decode('utf-8'))
                except (ValueError, UnicodeDecodeError):
                    return self._json_response({
                        'success': False,
                        'message': 'Format request tidak valid, data harus berformat JSON'
                    }, status=400)
            elif kwargs:
                body = kwargs
            elif getattr(request, 'params', None):
                body = dict(request.params)

            if not body or not isinstance(body, dict):
                return self._json_response({
                    'success': False,
                    'message': 'Request body tidak boleh kosong dan harus berupa objek JSON'
                }, status=400)

            # 4. Validasi Field Wajib (Name & Phone)
            name_raw = body.get('name')
            is_valid_name, name_or_err = self._validate_name(name_raw)
            if not is_valid_name:
                return self._json_response({
                    'success': False,
                    'message': name_or_err
                }, status=400)
            name = name_or_err

            phone_raw = body.get('phone')
            is_valid_phone, phone_or_err = self._validate_phone(phone_raw)
            if not is_valid_phone:
                return self._json_response({
                    'success': False,
                    'message': phone_or_err
                }, status=400)
            phone = phone_or_err

            # 5. Validasi dan Ekstraksi Field Opsional
            for opt_field in ('street', 'address', 'email', 'city'):
                opt_val = body.get(opt_field)
                if opt_val is not None and not isinstance(opt_val, str):
                    return self._json_response({
                        'success': False,
                        'message': f'Field {opt_field} harus berupa string yang valid'
                    }, status=400)

            street = body.get('street') or body.get('address') or ''
            street = street.strip() if isinstance(street, str) else ''

            email = body.get('email') or ''
            email = email.strip() if isinstance(email, str) else ''

            city = body.get('city') or ''
            city = city.strip() if isinstance(city, str) else ''

            # 6. Pembuatan Record Pelanggan via ORM Odoo
            vals = {
                'name': name,
                'phone': phone,
                'customer_rank': 1,
            }
            if street:
                vals['street'] = street
            if email:
                vals['email'] = email
            if city:
                vals['city'] = city

            new_partner = request.env['res.partner'].with_user(user).create(vals)

            # 7. Format data hasil respon
            return self._json_response({
                'success': True,
                'message': 'Pelanggan berhasil ditambahkan',
                'data': {
                    'id': new_partner.id,
                    'name': new_partner.name or '',
                    'phone': new_partner.phone or '',
                    'email': new_partner.email or '',
                    'street': new_partner.street or '',
                    'city': new_partner.city or '',
                    'address': new_partner.street or '',
                }
            }, status=201)

        except Exception as e:
            _logger.exception("Error creating customer: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan internal pada server'
            }, status=500)

    # Endpoint Penghapusan Pelanggan LaundryFlow
    @http.route(
        [
            '/api/laundry/customers/<string:customer_id>',
            '/api/customers/<string:customer_id>',
            '/api/laundry/customers/delete/<string:customer_id>',
            '/api/customers/delete/<string:customer_id>',
        ],
        type='http',
        auth='public',
        methods=['DELETE', 'OPTIONS'],
        csrf=False
    )
    def delete_customer(self, customer_id=None, **kwargs):
        if request.httprequest.method == 'OPTIONS':
            return self._json_response({'status': 'ok'})

        try:
            # 1. Autentikasi Pengguna
            user = self._get_authenticated_user()
            if not user:
                return self._json_response({
                    'success': False,
                    'message': 'Autentikasi diperlukan. Akses tidak diizinkan.'
                }, status=401)

            # 2. Hak Akses (Authorization)
            try:
                request.env['res.partner'].with_user(user).check_access('unlink')
            except AccessError:
                return self._json_response({
                    'success': False,
                    'message': 'Akses ditolak: Anda tidak memiliki izin untuk menghapus data pelanggan.'
                }, status=403)

            # 3. Validasi Parameter ID Pelanggan
            try:
                cid = int(str(customer_id).strip())
                if cid <= 0:
                    raise ValueError
            except (ValueError, TypeError):
                return self._json_response({
                    'success': False,
                    'message': 'ID pelanggan harus berupa angka positif yang valid'
                }, status=400)

            # 4. Cari Pelanggan Aktif
            partner = request.env['res.partner'].with_user(user).search([
                ('id', '=', cid),
                ('active', '=', True),
            ], limit=1)

            if not partner:
                return self._json_response({
                    'success': False,
                    'message': 'Data pelanggan tidak ditemukan'
                }, status=404)

            partner_info = {
                'id': partner.id,
                'name': partner.name or '',
                'phone': partner.phone or '',
            }

            # 5. Hapus Record Pelanggan (atau arsipkan jika terkait transaksi/referensi lain)
            try:
                with request.env.cr.savepoint():
                    partner.unlink()
            except Exception:
                partner.write({'active': False})

            return self._json_response({
                'success': True,
                'message': 'Pelanggan berhasil dihapus',
                'data': partner_info,
            }, status=200)

        except Exception as e:
            _logger.exception("Error deleting customer: %s", str(e))
            return self._json_response({
                'success': False,
                'message': 'Terjadi kesalahan internal pada server'
            }, status=500)
