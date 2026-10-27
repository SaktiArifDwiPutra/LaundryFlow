import json
import logging
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
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
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
