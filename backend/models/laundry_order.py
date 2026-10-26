
from odoo import api, fields, models, _
from odoo.exceptions import ValidationError


class LaundryOrder(models.Model):
    _name = "laundry.order"
    _description = "Pesanan Laundry"
    _order = "create_date desc, id desc"

    name = fields.Char(
        string="Nomor Pesanan",
        required=True,
        copy=False,
        readonly=True,
        default="New",
    )
    partner_id = fields.Many2one(
        "res.partner",
        string="Pelanggan",
        required=True,
    )
    service_type = fields.Selection(
        [
            ("wash_fold", "Cuci dan Lipat"),
            ("wash_iron", "Cuci dan Setrika"),
            ("iron", "Setrika"),
            ("dry_clean", "Dry Cleaning"),
        ],
        string="Layanan",
        required=True,
        default="wash_fold",
    )
    weight = fields.Float(
        string="Berat (kg)",
        required=True,
        default=1.0,
    )
    price_per_kg = fields.Float(
        string="Harga per Kg",
        required=True,
        default=7000.0,
    )
    total_amount = fields.Monetary(
        string="Total Harga",
        compute="_compute_total_amount",
        store=True,
        currency_field="currency_id",
    )
    currency_id = fields.Many2one(
        "res.currency",
        string="Mata Uang",
        required=True,
        default=lambda self: self.env.company.currency_id,
    )
    notes = fields.Text(string="Catatan")
    state = fields.Selection(
        [
            ("received", "Diterima"),
            ("washing", "Sedang Dicuci"),
            ("ironing", "Sedang Disetrika"),
            ("ready", "Siap Diambil"),
            ("completed", "Selesai"),
            ("cancelled", "Dibatalkan"),
        ],
        string="Status",
        required=True,
        default="received",
    )
    invoice_id = fields.Many2one(
        "account.move",
        string="Invoice",
        readonly=True,
        copy=False,
    )

    @api.depends("weight", "price_per_kg")
    def _compute_total_amount(self):
        for order in self:
            order.total_amount = order.weight * order.price_per_kg

    @api.constrains("weight", "price_per_kg")
    def _check_amounts(self):
        for order in self:
            if order.weight <= 0:
                raise ValidationError(_("Berat laundry harus lebih dari 0 kg."))
            if order.price_per_kg < 0:
                raise ValidationError(_("Harga per kg tidak boleh negatif."))

    @api.model_create_multi
    def create(self, vals_list):
        sequence = self.env["ir.sequence"]
        for vals in vals_list:
            if vals.get("name", "New") == "New":
                vals["name"] = sequence.next_by_code("laundry.order") or "New"
        return super().create(vals_list)
