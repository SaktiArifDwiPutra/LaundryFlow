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
    laundry_expiring_soon_days = fields.Integer(
        string="Batas Hari Segera Kedaluwarsa",
        config_parameter="laundry.expiring_soon_days",
        default=30,
        help="Batas jumlah hari tersisa sebelum tanggal kedaluwarsa untuk dikategorikan sebagai 'Segera Kedaluwarsa' (expiring_soon).",
    )
    currency_id = fields.Many2one(
        "res.currency",
        string="Mata Uang",
        default=lambda self: self.env.company.currency_id,
    )
