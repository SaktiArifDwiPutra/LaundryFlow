"""
LaundryFlow Controllers Facade.
Provides re-exports for modular controllers and maintains backward compatibility.
"""
from .base import BaseApiController
from .auth_controller import AuthController
from .customer_controller import CustomerApiController
from .product_controller import ProductApiController
from odoo.http import request, Response
from odoo.http.session import session_store, authenticate, save_session

__all__ = [
    'BaseApiController',
    'AuthController',
    'CustomerApiController',
    'ProductApiController',
    'request',
    'Response',
    'session_store',
    'authenticate',
    'save_session',
]
