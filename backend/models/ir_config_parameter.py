# -*- coding: utf-8 -*-
from odoo import models, api


class IrConfigParameter(models.Model):
    _inherit = 'ir.config_parameter'

    @api.model
    def get_param(self, key, default=False):
        """Odoo 20 compatibility helper for legacy get_param calls."""
        val = self.get_str(key, default=None)
        if val is None:
            return default
        return val

    @api.model
    def set_param(self, key, value):
        """Odoo 20 compatibility helper for legacy set_param calls."""
        return self.set_str(key, str(value) if value is not None else '')
