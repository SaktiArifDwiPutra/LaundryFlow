# -*- coding: utf-8 -*-
from odoo import models, fields, api
from odoo.exceptions import ValidationError


class ProductTemplate(models.Model):
    _inherit = 'product.template'

    is_laundry_material = fields.Boolean(
        string='Bahan Laundry',
        compute='_compute_is_laundry_material',
        store=True,
        help='True jika produk merupakan bagian dari kategori Bahan Laundry'
    )
    min_stock_qty = fields.Float(
        string='Stok Minimum',
        compute='_compute_inventory_status',
        help='Batas minimum stok untuk peringatan stok rendah dari aturan reordering'
    )
    is_low_stock = fields.Boolean(
        string='Peringatan Stok Rendah',
        compute='_compute_inventory_status',
        help='True jika stok aktual kurang dari atau sama dengan minimum stok'
    )
    has_expired_batches = fields.Boolean(
        string='Ada Batch Kedaluwarsa',
        compute='_compute_inventory_status',
        help='True jika terdapat batch bertanggal kedaluwarsa lampau yang masih memiliki stok'
    )
    batch_count = fields.Integer(
        string='Jumlah Batch',
        compute='_compute_inventory_status',
        help='Jumlah lot/batch yang tercatat untuk produk ini'
    )

    @api.depends('categ_id', 'categ_id.name', 'categ_id.parent_id')
    def _compute_is_laundry_material(self):
        for tmpl in self:
            tmpl.is_laundry_material = bool(
                tmpl.categ_id and (
                    tmpl.categ_id.name == 'Bahan Laundry' or
                    (tmpl.categ_id.parent_id and tmpl.categ_id.parent_id.name == 'Bahan Laundry')
                )
            )

    def _compute_inventory_status(self):
        for tmpl in self:
            product = tmpl.product_variant_id
            if product:
                tmpl.min_stock_qty = product.min_stock_qty
                tmpl.is_low_stock = product.is_low_stock
                tmpl.has_expired_batches = product.has_expired_batches
                tmpl.batch_count = product.batch_count
            else:
                tmpl.min_stock_qty = 0.0
                tmpl.is_low_stock = False
                tmpl.has_expired_batches = False
                tmpl.batch_count = 0

    def init(self):
        """
        Memastikan kelima produk bahan laundry (SKU berawalan MAT-)
        memiliki use_expiration_date=True, tracking='lot', dan is_storable=True.
        """
        super().init()
        # Jalankan update konfigurasi ORM jika model sudah siap
        try:
            materials = self.search([('default_code', '=like', 'MAT-%')])
            for mat in materials:
                vals = {}
                if not mat.use_expiration_date:
                    vals['use_expiration_date'] = True
                if mat.tracking != 'lot':
                    vals['tracking'] = 'lot'
                if not mat.is_storable:
                    vals['is_storable'] = True
                if vals:
                    mat.write(vals)
        except Exception:
            pass




class ProductProduct(models.Model):
    _inherit = 'product.product'

    min_stock_qty = fields.Float(
        string='Stok Minimum',
        compute='_compute_material_inventory_status',
        help='Batas minimum stok untuk peringatan stok rendah dari reordering rule'
    )
    is_low_stock = fields.Boolean(
        string='Peringatan Stok Rendah',
        compute='_compute_material_inventory_status',
        help='True jika stok aktual kurang dari atau sama dengan minimum stok'
    )
    has_expired_batches = fields.Boolean(
        string='Ada Batch Kedaluwarsa',
        compute='_compute_material_inventory_status',
        help='True jika terdapat batch bertanggal kedaluwarsa lampau yang masih memiliki stok'
    )
    batch_count = fields.Integer(
        string='Jumlah Batch',
        compute='_compute_material_inventory_status',
        help='Jumlah lot/batch yang tercatat untuk produk ini'
    )

    def _compute_material_inventory_status(self):
        Orderpoint = self.env['stock.warehouse.orderpoint']
        Lot = self.env['stock.lot']
        for product in self:
            # Cari aturan minimum stok
            orderpoints = Orderpoint.search([('product_id', '=', product.id)], limit=1)
            min_qty = orderpoints.product_min_qty if orderpoints else 0.0
            product.min_stock_qty = min_qty

            actual_stock = product.qty_available
            product.is_low_stock = (min_qty > 0.0 and actual_stock <= min_qty)

            # Cari lot aktif
            lots = Lot.search([('product_id', '=', product.id)])
            product.batch_count = len(lots)

            has_expired = False
            for lot in lots:
                if lot.product_qty > 0.0 and lot.is_expired:
                    has_expired = True
                    break
            product.has_expired_batches = has_expired

    def set_min_stock(self, min_qty, max_qty=None, location=None):
        """
        Mengeset batas minimum stok untuk produk bahan menggunakan ORM stock.warehouse.orderpoint.
        """
        self.ensure_one()
        if min_qty < 0:
            raise ValidationError("Stok minimum tidak boleh negatif.")

        Orderpoint = self.env['stock.warehouse.orderpoint']
        company_id = self.env.company.id

        if not location:
            warehouse = self.env['stock.warehouse'].search([('company_id', '=', company_id)], limit=1)
            location_obj = warehouse.lot_stock_id if warehouse else self.env.ref('stock.stock_location_stock', raise_if_not_found=False)
        else:
            location_obj = location if isinstance(location, models.Model) else self.env['stock.location'].browse(location)

        orderpoint = Orderpoint.search([
            ('product_id', '=', self.id),
            ('company_id', '=', company_id)
        ], limit=1)

        vals = {
            'product_min_qty': min_qty,
            'product_max_qty': max_qty if max_qty is not None else max(min_qty * 2.0, min_qty),
        }
        if location_obj:
            vals['location_id'] = location_obj.id

        if orderpoint:
            orderpoint.write(vals)
        else:
            vals.update({
                'product_id': self.id,
                'company_id': company_id,
            })
            orderpoint = Orderpoint.create(vals)

        return orderpoint

    def get_batches_info(self):
        """
        Mengembalikan informasi seluruh batch untuk produk bahan laundry ini.
        Mendukung kedaluwarsa per batch, batch tanpa kedaluwarsa, kuantitas batch, dan supplier.
        """
        self.ensure_one()
        Lot = self.env['stock.lot']
        lots = Lot.search([('product_id', '=', self.id)], order='expiration_date asc, id asc')

        batch_list = []
        for lot in lots:
            batch_list.append({
                'lot_id': lot.id,
                'batch_number': lot.name,
                'received_date': lot.receipt_date.isoformat() if lot.receipt_date else (lot.create_date.date().isoformat() if lot.create_date else None),
                'expiration_date': lot.expiration_date.isoformat() if lot.expiration_date else None,
                'quantity': lot.product_qty,
                'supplier_id': lot.supplier_id.id if lot.supplier_id else None,
                'supplier_name': lot.supplier_id.name if lot.supplier_id else None,
                'is_expired': lot.is_expired,
                'days_to_expiration': lot.days_to_expiration,
                'expiration_status': lot.expiration_status,
            })
        return batch_list

    def receive_batch(self, lot_name, qty, receipt_date=None, expiration_date=None, supplier=None, location=None):
        """
        Shortcut helper untuk mencatat penerimaan batch pada produk ini menggunakan ORM.
        """
        self.ensure_one()
        return self.env['stock.lot'].receive_batch(
            product=self,
            lot_name=lot_name,
            qty=qty,
            receipt_date=receipt_date,
            expiration_date=expiration_date,
            supplier=supplier,
            location=location
        )

