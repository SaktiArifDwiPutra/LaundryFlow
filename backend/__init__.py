# -*- coding: utf-8 -*-
# Monkeypatch Odoo 20 core bug in fields_binary.py where convert_to_cache crashes
# if dict has empty content and a filename (AttributeError: 'NoneType' object has no attribute 'filename')
try:
    from odoo.orm import fields_binary

    _orig_convert_to_cache = fields_binary.Binary.convert_to_cache

    def _safe_convert_to_cache(self, value, records, validate=True):
        if isinstance(value, dict) and 'content' in value:
            filename = value.get('filename') or ''
            binary_value = self.convert_to_cache(value['content'], records)
            if filename and binary_value and binary_value.filename != filename:
                binary_value = fields_binary.BinaryBytes(binary_value.content, filename=filename)
            return binary_value
        return _orig_convert_to_cache(self, value, records, validate=validate)

    fields_binary.Binary.convert_to_cache = _safe_convert_to_cache
except Exception:
    pass

from . import models
from . import controllers

