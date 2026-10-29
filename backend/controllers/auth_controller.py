import json
import logging
from odoo import http
from odoo.http import request
from odoo.http.session import authenticate, save_session
from .base import BaseApiController

_logger = logging.getLogger(__name__)


class AuthController(BaseApiController):
    """Controller for user authentication and session token generation."""

    @http.route(
        ['/api/laundry/auth/login', '/api/auth/login'],
        type='http',
        auth='none',
        methods=['POST', 'OPTIONS'],
        csrf=False
    )
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
