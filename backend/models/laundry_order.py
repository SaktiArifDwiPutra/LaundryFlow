from odoo import api, fields, models, _
from odoo.exceptions import ValidationError


class LaundryOrder(models.Model):
    _name = "laundry.order"
    _description = "Pesanan Laundry"
    _order = "order_date desc, create_date desc, id desc"

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
        index=True,
    )
    order_date = fields.Datetime(
        string="Tanggal Pesanan",
        default=fields.Datetime.now,
        required=True,
        copy=False,
        index=True,
        help="Tanggal dan waktu pesanan laundry diterima.",
    )
    service_speed = fields.Selection(
        [
            ("regular", "Reguler"),
            ("same_day", "Same Day Service"),
        ],
        string="Jenis Pengerjaan",
        required=True,
        default="regular",
        help="Pilihan kecepatan pengerjaan pesanan: Reguler atau Same Day Service.",
    )
    user_id = fields.Many2one(
        "res.users",
        string="Pegawai / Operator",
        default=lambda self: self.env.user,
        index=True,
        help="Pegawai atau operator yang menangani pesanan.",
    )
    line_ids = fields.One2many(
        "laundry.order.line",
        "order_id",
        string="Detail Layanan",
        copy=True,
    )
    item_details = fields.Text(
        string="Detail Barang",
        help="Catatan keseluruhan rincian pakaian/barang pelanggan (misal: 5 kemeja, 3 celana, 1 sprei).",
    )
    service_type = fields.Selection(
        [
            ("wash_fold", "Cuci dan Lipat"),
            ("wash_iron", "Cuci dan Setrika"),
            ("iron", "Setrika"),
            ("dry_clean", "Dry Cleaning"),
        ],
        string="Layanan (Legacy)",
        required=False,
        default="wash_fold",
    )
    weight = fields.Float(
        string="Berat Total (kg)",
        compute="_compute_weight",
        precompute=True,
        store=True,
        readonly=False,
        default=0.0,
    )
    price_per_kg = fields.Float(
        string="Harga per Kg (Legacy)",
        required=False,
        default=0.0,
    )
    total_amount = fields.Monetary(
        string="Total Harga",
        compute="_compute_total_amount",
        precompute=True,
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
        index=True,
    )
    invoice_id = fields.Many2one(
        "account.move",
        string="Invoice",
        readonly=True,
        copy=False,
    )

    @api.depends("line_ids.subtotal", "weight", "price_per_kg")
    def _compute_total_amount(self):
        for order in self:
            if order.line_ids:
                order.total_amount = sum(order.line_ids.mapped("subtotal"))
            else:
                # Kompatibilitas mundur dengan transaksi legacy tunggal
                order.total_amount = (order.weight or 0.0) * (order.price_per_kg or 0.0)

    @api.depends("line_ids.quantity", "line_ids.pricing_type")
    def _compute_weight(self):
        for order in self:
            if order.line_ids:
                weight_lines = order.line_ids.filtered(lambda l: l.pricing_type == "weight")
                order.weight = sum(weight_lines.mapped("quantity")) if weight_lines else 0.0

    @api.constrains("weight", "price_per_kg")
    def _check_amounts(self):
        for order in self:
            if not order.line_ids:
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
            # Backend menghitung ulang: jangan mempercayai total_amount dari payload klien
            if "total_amount" in vals and ("line_ids" in vals or vals.get("line_ids")):
                vals.pop("total_amount", None)
        orders = super().create(vals_list)
        for order in orders:
            order._compute_weight()
            order._compute_total_amount()
        return orders

    def recompute_prices(self):
        """
        Memaksa backend menghitung ulang semua subtotal dan total harga pesanan.
        """
        for order in self:
            order.line_ids._compute_subtotal()
            order._compute_weight()
            order._compute_total_amount()
        return True


class LaundryOrderLine(models.Model):
    _name = "laundry.order.line"
    _description = "Detail Layanan Pesanan Laundry"
    _order = "order_id, id"

    @api.model
    def _determine_pricing_type(self, uom_name):
        uom = (uom_name or "").lower()
        if any(w in uom for w in ["kg", "g", "gram", "kilogram"]):
            return "weight"
        elif any(a in uom for a in ["m²", "m2", "sqm", "meter persegi"]):
            return "area"
        elif "set" in uom:
            return "set"
        return "unit"

    @api.model
    def _get_uom_category_or_root(self, uom):
        if not uom:
            return None
        if hasattr(uom, "category_id") and uom.category_id:
            return uom.category_id.id
        if hasattr(uom, "parent_path") and uom.parent_path:
            return uom.parent_path.split("/")[0]
        return uom.id

    order_id = fields.Many2one(
        "laundry.order",
        string="Pesanan",
        required=True,
        ondelete="cascade",
        index=True,
    )
    product_template_id = fields.Many2one(
        "product.template",
        string="Layanan Laundry",
        required=True,
        domain="[('type', '=', 'service')]",
    )
    product_id = fields.Many2one(
        "product.product",
        string="Varian Layanan",
        compute="_compute_product_id",
        store=True,
        readonly=False,
    )
    name = fields.Char(
        string="Deskripsi Layanan",
    )
    item_details = fields.Text(
        string="Detail Barang",
        help="Rincian pakaian atau barang pada detail layanan ini (misal: 3 kemeja katun, 2 celana jeans).",
    )
    user_id = fields.Many2one(
        "res.users",
        string="Pegawai Penangan",
        related="order_id.user_id",
        store=True,
        readonly=False,
        help="Pegawai yang menangani detail layanan ini.",
    )
    pricing_type = fields.Selection(
        [
            ("weight", "Per Kg (Berat)"),
            ("unit", "Per Pcs (Satuan)"),
            ("set", "Per Set"),
            ("area", "Per M² (Luas)"),
        ],
        string="Tipe Perhitungan",
        compute="_compute_pricing_type",
        precompute=True,
        store=True,
        readonly=False,
        default="unit",
    )
    uom_id = fields.Many2one(
        "uom.uom",
        string="Satuan",
        compute="_compute_uom_id",
        precompute=True,
        store=True,
        readonly=False,
        required=True,
    )

    # Dimensi untuk Luas (Karpet / m²) - Ketentuan 1, 2, 3, 4
    length = fields.Float(
        string="Panjang (m)",
        digits=(12, 2),
        default=0.0,
        help="Panjang karpet dalam satuan meter. Harus angka positif > 0.",
    )
    width = fields.Float(
        string="Lebar (m)",
        digits=(12, 2),
        default=0.0,
        help="Lebar karpet dalam satuan meter. Harus angka positif > 0.",
    )
    area = fields.Float(
        string="Luas (m²)",
        digits=(12, 2),
        compute="_compute_area",
        precompute=True,
        store=True,
        help="Luas dalam meter persegi = panjang × lebar.",
    )

    # Jumlah / Kuantitas (kg / pcs / set / helai karpet)
    quantity = fields.Float(
        string="Jumlah / Kuantitas",
        digits=(12, 2),
        default=1.0,
        required=True,
        help="Berat (kg) jika per kg, jumlah (pcs) jika per pcs, jumlah set jika per set, atau jumlah helai jika per m².",
    )
    weight = fields.Float(
        string="Berat (kg)",
        digits=(12, 2),
        compute="_compute_line_weight",
        precompute=True,
        store=True,
        readonly=False,
        help="Berat barang dalam kg (khusus layanan per berat/kg).",
    )

    # Snapshot Harga - Ketentuan 9 & 10
    price_unit = fields.Monetary(
        string="Harga Satuan (Snapshot)",
        currency_field="currency_id",
        required=True,
        help="Snapshot harga satuan dari katalog Odoo saat transaksi dibuat. Perubahan harga katalog di masa depan tidak mempengaruhi transaksi lama.",
    )
    subtotal = fields.Monetary(
        string="Subtotal",
        compute="_compute_subtotal",
        precompute=True,
        store=True,
        currency_field="currency_id",
        help="Subtotal harga yang dihitung ulang oleh backend.",
    )
    currency_id = fields.Many2one(
        "res.currency",
        related="order_id.currency_id",
        string="Mata Uang",
        store=True,
    )
    notes = fields.Char(string="Catatan")

    @api.depends("quantity", "pricing_type")
    def _compute_line_weight(self):
        for line in self:
            if line.pricing_type == "weight":
                line.weight = line.quantity or 0.0
            else:
                line.weight = 0.0

    @api.depends("product_template_id")
    def _compute_product_id(self):
        for line in self:
            if line.product_template_id and not line.product_id:
                variant = line.product_template_id.product_variant_id or self.env["product.product"].search(
                    [("product_tmpl_id", "=", line.product_template_id.id)], limit=1
                )
                line.product_id = variant.id if variant else False

    @api.depends("product_template_id", "product_template_id.uom_id")
    def _compute_pricing_type(self):
        for line in self:
            if not line.product_template_id:
                if not line.pricing_type:
                    line.pricing_type = "unit"
                continue
            line.pricing_type = self._determine_pricing_type(line.product_template_id.uom_id.name)

    @api.depends("product_template_id")
    def _compute_uom_id(self):
        for line in self:
            if line.product_template_id and not line.uom_id:
                line.uom_id = line.product_template_id.uom_id

    @api.depends("length", "width", "pricing_type")
    def _compute_area(self):
        for line in self:
            if line.pricing_type == "area":
                line.area = line._calculate_area(line.length, line.width)
            else:
                line.area = 0.0

    def _calculate_area(self, length, width):
        """
        Menghitung luas karpet dalam satuan meter persegi (m²).
        Sesuai Ketentuan 5 & 6:
        - Default: Luas = panjang × lebar (tanpa membuat aturan pembulatan sendiri, menunggu keputusan bisnis).
        - Jika aturan pembulatan dikonfigurasi melalui ir.config_parameter (misal laundry.area_rounding_method),
          sistem menerapkan konfigurasi tersebut.
        """
        if length <= 0 or width <= 0:
            return 0.0
        raw_area = length * width

        param_obj = self.env["ir.config_parameter"].sudo()
        if hasattr(param_obj, "get_str"):
            rounding_method = param_obj.get_str("laundry.area_rounding_method", "none")
        elif hasattr(param_obj, "get_param"):
            rounding_method = param_obj.get_param("laundry.area_rounding_method", "none")
        else:
            rec = param_obj.search([("key", "=", "laundry.area_rounding_method")], limit=1)
            rounding_method = rec.value if rec else "none"

        if rounding_method == "ceil":
            import math
            return float(math.ceil(raw_area))
        elif rounding_method == "round":
            if hasattr(param_obj, "get_int"):
                decimals = param_obj.get_int("laundry.area_rounding_decimals", 2)
            else:
                decimals = 2
            return round(raw_area, decimals)

        return raw_area

    @api.depends("pricing_type", "quantity", "area", "price_unit", "length", "width")
    def _compute_subtotal(self):
        """
        Perhitungan harga backend:
        - A. BERDASARKAN KG: Total = berat × harga per kg
        - B. BERDASARKAN PCS: Total = jumlah × harga per pcs
        - C. BERDASARKAN SET: Total = jumlah set × harga per set
        - D. BERDASARKAN M²: Luas karpet = panjang × lebar, Total karpet = luas × harga per m²
        """
        for line in self:
            price = line.price_unit or 0.0
            qty = line.quantity if line.quantity is not None else 1.0

            if line.pricing_type == "weight":
                line.subtotal = qty * price
            elif line.pricing_type == "unit":
                line.subtotal = qty * price
            elif line.pricing_type == "set":
                line.subtotal = qty * price
            elif line.pricing_type == "area":
                calc_area = line.area if line.area else line._calculate_area(line.length, line.width)
                line.subtotal = calc_area * price * (qty if qty > 0 else 1.0)
            else:
                line.subtotal = qty * price

    @api.onchange("product_template_id")
    def _onchange_product_template_id(self):
        if self.product_template_id:
            self.name = self.product_template_id.name
            self.price_unit = self.product_template_id.list_price
            self.uom_id = self.product_template_id.uom_id
            self.pricing_type = self._determine_pricing_type(self.product_template_id.uom_id.name)

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            tmpl_id = vals.get("product_template_id")
            if tmpl_id:
                tmpl = self.env["product.template"].browse(tmpl_id)
                if not vals.get("name"):
                    vals["name"] = tmpl.name
                if not vals.get("pricing_type"):
                    vals["pricing_type"] = self._determine_pricing_type(tmpl.uom_id.name)
                # Snapshot harga katalog Odoo saat transaksi dibuat jika belum terisi
                if "price_unit" not in vals or vals.get("price_unit") is None:
                    vals["price_unit"] = tmpl.list_price
                if "uom_id" not in vals or not vals.get("uom_id"):
                    vals["uom_id"] = tmpl.uom_id.id
            if not vals.get("pricing_type"):
                vals["pricing_type"] = "unit"
        lines = super().create(vals_list)
        for line in lines:
            line._compute_area()
            line._compute_subtotal()
            line._compute_line_weight()
        return lines

    @api.constrains("product_template_id")
    def _check_product_service(self):
        for line in self:
            if not line.product_template_id:
                raise ValidationError(_("Setiap detail pesanan wajib terhubung ke produk Odoo."))
            if line.product_template_id.type != "service":
                raise ValidationError(_(
                    "Produk '%(product)s' bukan merupakan produk layanan laundry (tipe produk harus 'service').",
                    product=line.product_template_id.name,
                ))

    @api.constrains("product_template_id", "uom_id")
    def _check_uom_compatibility(self):
        for line in self:
            if not line.uom_id:
                raise ValidationError(_("Satuan (UoM) wajib diisi untuk setiap detail layanan."))
            if line.product_template_id and line.product_template_id.uom_id:
                prod_uom = line.product_template_id.uom_id
                if line.uom_id.id != prod_uom.id:
                    line_root = self._get_uom_category_or_root(line.uom_id)
                    prod_root = self._get_uom_category_or_root(prod_uom)
                    if line_root != prod_root:
                        raise ValidationError(_(
                            "Satuan '%(uom)s' tidak kompatibel dengan produk layanan '%(product)s'.",
                            uom=line.uom_id.name,
                            product=line.product_template_id.name,
                        ))

    @api.constrains("pricing_type", "length", "width")
    def _check_area_dimensions(self):
        for line in self:
            if line.pricing_type == "area":
                if line.length <= 0:
                    raise ValidationError(_("Detail karpet wajib memiliki panjang berupa angka positif lebih dari 0 meter."))
                if line.width <= 0:
                    raise ValidationError(_("Detail karpet wajib memiliki lebar berupa angka positif lebih dari 0 meter."))

    @api.constrains("pricing_type", "quantity")
    def _check_quantity(self):
        for line in self:
            if line.quantity <= 0:
                raise ValidationError(_("Jumlah atau berat layanan harus berupa angka positif lebih dari 0."))

    @api.constrains("price_unit")
    def _check_price_unit(self):
        for line in self:
            if line.price_unit < 0:
                raise ValidationError(_("Harga satuan tidak boleh negatif."))
