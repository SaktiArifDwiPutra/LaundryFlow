import json
import logging
from odoo import http
from odoo.http import request as default_request, Response
from odoo.http.session import session_store as default_session_store

_logger = logging.getLogger(__name__)


class BaseApiController(http.Controller):
    """
    Base API Controller providing shared JSON response formatting, CORS handling,
    and unified authentication helpers across all LaundryFlow API controllers.
    """

    def _json_response(self, data, status=200):
        """Helper to format JSON responses with standard CORS headers."""
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

    def _get_authenticated_user(self, req=None, session_store_fn=None):
        """
        Validates authentication and returns the active res.users record.
        Returns None if request is unauthenticated or belongs to a public user.
        Supports:
        - Active Odoo HTTP session (req.session.uid)
        - Header 'Authorization: Bearer <session_id>'
        - Header 'Authorization: Token <session_id>'
        - Header 'X-Session-Id: <session_id>'
        - Header 'X-Api-Key: <api_key>'
        - Query parameters 'session_id' or 'api_key'
        """
        req = req if req is not None else default_request
        store_lookup = session_store_fn or default_session_store

        # 1. Check standard active session
        uid = getattr(req.session, 'uid', None)
        if uid:
            user = req.env['res.users'].sudo().browse(uid)
            if user.exists() and not user._is_public():
                return user

        # 2. Extract token from headers or query parameters
        auth_header = req.httprequest.headers.get('Authorization') or ''
        token = None
        if auth_header.startswith('Bearer '):
            token = auth_header.split(' ', 1)[1].strip()
        elif auth_header.startswith('Token '):
            token = auth_header.split(' ', 1)[1].strip()

        if not token:
            token = (
                req.httprequest.headers.get('X-Session-Id')
                or req.httprequest.headers.get('X-Api-Key')
                or req.params.get('session_id')
                or req.params.get('api_key')
            )

        if token:
            # 2a. Lookup in session store
            try:
                store = store_lookup()
                session = store.get(token)
                if session and session.get('uid'):
                    user = req.env['res.users'].sudo().browse(session.get('uid'))
                    if user.exists() and not user._is_public():
                        return user
            except Exception as e:
                _logger.debug("Session lookup failed: %s", e)

            # 2b. Lookup via res.users.apikeys if applicable
            try:
                if 'res.users.apikeys' in req.env:
                    key_uid = req.env['res.users.apikeys'].sudo()._check_credentials(scope='rpc', key=token)
                    if key_uid:
                        user = req.env['res.users'].sudo().browse(key_uid)
                        if user.exists() and not user._is_public():
                            return user
            except Exception as e:
                _logger.debug("API key lookup failed: %s", e)

        # 3. Request env user fallback if valid and non-public
        if hasattr(req, 'env') and req.env.user and not req.env.user._is_public():
            return req.env.user

        return None
