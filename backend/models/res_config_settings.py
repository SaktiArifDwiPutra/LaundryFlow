from odoo import fields, models


class ResConfigSettings(models.TransientModel):
    _inherit = "res.config.settings"

    laundry_same_day_available = fields.Boolean(
        string="Same Day Service Tersedia",
        config_parameter="laundry.same_day_available",
        default=True,
        help="Aktifkan agar pelanggan dapat memilih opsi pengerjaan Same Day Service pada pesanan.",
    )
    laundry_same_day_surcharge = fields.Monetary(
        string="Biaya Tambahan Same Day Service",
        config_parameter="laundry.same_day_surcharge",
        currency_field="currency_id",
        default=0.0,
        help="Biaya tambahan untuk jenis pengerjaan Same Day Service jika sudah dikonfirmasi secara operasional. Default 0.",
    )
    currency_id = fields.Many2one(
        "res.currency",
        string="Mata Uang",
        default=lambda self: self.env.company.currency_id,
    )
