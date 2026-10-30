# -*- coding: utf-8 -*-
from datetime import date, datetime
from odoo import models, fields, api
from odoo.exceptions import ValidationError


class StockLot(models.Model):
    _inherit = 'stock.lot'

    supplier_id = fields.Many2one(
        'res.partner',
        string='Supplier',
        domain="[('is_company', '=', True)]",
        help='Supplier yang menyediakan batch/lot barang ini'
    )
    receipt_date = fields.Date(
        string='Tanggal Penerimaan',
        default=fields.Date.context_today,
        help='Tanggal batch diterima di gudang'
    )
    days_to_expiration = fields.Integer(
        string='Hari Menuju Kedaluwarsa',
        compute='_compute_expiration_info',
        store=False,
        help='Jumlah hari tersisa sebelum kedaluwarsa (negatif jika sudah lewat)'
    )
    is_expired = fields.Boolean(
        string='Sudah Kedaluwarsa',
        compute='_compute_expiration_info',
        search='_search_is_expired',
        store=False,
        help='True jika batch ini telah melewati tanggal kedaluwarsa'
    )
    expiration_status = fields.Selection(
        [
            ('safe', 'Aman'),
            ('expiring_soon', 'Segera Kedaluwarsa'),
            ('expired', 'Kedaluwarsa'),
            ('unknown', 'Tanpa Kedaluwarsa'),
        ],
        string='Status Kedaluwarsa',
        compute='_compute_expiration_info',
        store=False,
        help='Status kedaluwarsa batch berdasarkan tanggal kedaluwarsa'
    )

    @api.model
    def _get_expiring_soon_days_threshold(self):
        """Batas hari untuk status expiring_soon dari konfigurasi Odoo (default: 30 hari)."""
        param = self.env['ir.config_parameter'].sudo().get_param('laundry.expiring_soon_days', '30')
        try:
            return int(param)
        except (ValueError, TypeError):
            return 30

    @api.depends('expiration_date')
    def _compute_expiration_info(self):
        today = fields.Date.context_today(self)
        threshold_days = self._get_expiring_soon_days_threshold()
        for lot in self:
            if not lot.expiration_date:
                lot.days_to_expiration = 0
                lot.is_expired = False
                lot.expiration_status = 'unknown'
            else:
                exp_date = fields.Date.to_date(lot.expiration_date)
                delta_days = (exp_date - today).days
                lot.days_to_expiration = delta_days
                lot.is_expired = delta_days < 0
                if delta_days < 0:
                    lot.expiration_status = 'expired'
                elif delta_days <= threshold_days:
                    lot.expiration_status = 'expiring_soon'
                else:
                    lot.expiration_status = 'safe'

    def _search_is_expired(self, operator, value):
        now = fields.Datetime.now()
        if (operator == '=' and value is True) or (operator == '!=' and value is False):
            return [('expiration_date', '!=', False), ('expiration_date', '<', now)]
        else:
            return ['|', ('expiration_date', '=', False), ('expiration_date', '>=', now)]

    @api.model
    def receive_batch(self, product, lot_name, qty, receipt_date=None, expiration_date=None, supplier=None, location=None):
        """
        ORM helper untuk mencatat penerimaan batch inventory bahan laundry.
        Menggunakan mekanisme inventory standar Odoo (stock.quant) tanpa query SQL langsung.
        Menjaga riwayat pergerakan dan lot tracking.
        """
        if qty <= 0:
            raise ValidationError("Kuantitas batch penerimaan harus berupa angka positif lebih dari 0.")
        if not lot_name or not str(lot_name).strip():
            raise ValidationError("Nomor lot/batch wajib diisi.")

        product_obj = product if isinstance(product, models.Model) else self.env['product.product'].browse(product)
        if not product_obj.exists():
            raise ValidationError("Produk bahan tidak ditemukan.")

        company_id = self.env.company.id

        # Tentukan lokasi gudang internal
        if not location:
            warehouse = self.env['stock.warehouse'].search([('company_id', '=', company_id)], limit=1)
            location_obj = warehouse.lot_stock_id if warehouse else self.env.ref('stock.stock_location_stock', raise_if_not_found=False)
            if not location_obj:
                location_obj = self.env['stock.location'].search([('usage', '=', 'internal'), ('company_id', 'in', (False, company_id))], limit=1)
        else:
            location_obj = location if isinstance(location, models.Model) else self.env['stock.location'].browse(location)

        if not location_obj or not location_obj.exists():
            raise ValidationError("Lokasi internal gudang untuk penyimpanan bahan tidak ditemukan.")

        # Cari atau buat record stock.lot
        lot = self.search([
            ('product_id', '=', product_obj.id),
            ('name', '=', str(lot_name).strip()),
            ('company_id', 'in', (False, company_id))
        ], limit=1)

        lot_vals = {}
        if receipt_date:
            lot_vals['receipt_date'] = receipt_date
        if expiration_date:
            lot_vals['expiration_date'] = expiration_date
        if supplier:
            supplier_id = supplier.id if isinstance(supplier, models.Model) else supplier
            lot_vals['supplier_id'] = supplier_id

        if lot:
            if lot_vals:
                lot.write(lot_vals)
        else:
            create_vals = {
                'name': str(lot_name).strip(),
                'product_id': product_obj.id,
                'company_id': company_id,
            }
            create_vals.update(lot_vals)
            lot = self.create(create_vals)

        # Update kuantitas stok menggunakan ORM resmi Odoo (stock.quant._update_available_quantity)
        self.env['stock.quant']._update_available_quantity(
            product_obj,
            location_obj,
            quantity=qty,
            lot_id=lot
        )

        return lot

