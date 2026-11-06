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
        index=True,
        help="Pilihan kecepatan pengerjaan pesanan: Reguler atau Same Day Service.",
    )
    service_speed_fee = fields.Monetary(
        string="Biaya Jenis Pengerjaan",
        currency_field="currency_id",
        default=0.0,
        help="Snapshot biaya tambahan jenis pengerjaan (misal Same Day Service) saat transaksi dibuat. Perubahan konfigurasi di masa depan tidak mempengaruhi transaksi lama.",
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
            ("drying", "Sedang Dikeringkan"),
            ("ironing", "Sedang Disetrika"),
            ("ready", "Siap Diambil / Siap Kirim"),
            ("out_for_delivery", "Dalam Pengiriman"),
            ("completed", "Selesai"),
            ("cancelled", "Dibatalkan"),
        ],
        string="Status",
        required=True,
        default="received",
        index=True,
        copy=False,
        help="Alur status pengerjaan pesanan laundry.",
    )
    delivery_type = fields.Selection(
        [
            ("pickup", "Ambil Sendiri (Pickup)"),
            ("delivery", "Antar ke Alamat (Delivery)"),
        ],
        string="Metode Pengambilan",
        required=True,
        default="pickup",
        index=True,
        help="Metode penyerahan cucian kepada pelanggan: Ambil sendiri di tempat (pickup) atau diantar kurir (delivery).",
    )
    delivery_address = fields.Text(
        string="Alamat Pengantaran",
        help="Alamat pengiriman cucian jika metode pengantaran adalah delivery.",
    )
    delivery_fee = fields.Monetary(
        string="Biaya Ongkir",
        currency_field="currency_id",
        default=0.0,
        help="Biaya ongkos kirim jika layanan diantar ke alamat pelanggan.",
    )
    invoice_id = fields.Many2one(
        "account.move",
        string="Invoice",
        readonly=True,
        copy=False,
    )

    # -------------------------------------------------------------------------
    # Integrasi WhatsApp Tracking & Outbox
    # -------------------------------------------------------------------------
    whatsapp_phone = fields.Char(
        string="Nomor WhatsApp",
        copy=False,
        help="Nomor WhatsApp pelanggan untuk pengiriman notifikasi (format: 628xxx).",
    )
    whatsapp_sent = fields.Boolean(
        string="WhatsApp Terkirim",
        default=False,
        readonly=True,
        copy=False,
        help="Menandakan apakah notifikasi WhatsApp telah berhasil dikirim ke pelanggan.",
    )
    whatsapp_last_sent = fields.Datetime(
        string="Waktu Kirim WA Terakhir",
        readonly=True,
        copy=False,
        help="Waktu terakhir pengiriman pesan WhatsApp pada pesanan ini.",
    )
    whatsapp_outbox_ids = fields.Many2many(
        "infinys.wapi.outbox",
        "laundry_order_wapi_outbox_rel",
        "order_id",
        "outbox_id",
        string="Riwayat Pesan WhatsApp",
        copy=False,
        help="Daftar riwayat pesan WhatsApp yang telah dibuat/dikirim untuk pesanan ini.",
    )
    whatsapp_status = fields.Selection(
        [
            ("not_sent", "Belum Dikirim"),
            ("pending", "Dalam Antrean"),
            ("delivered", "Terkirim"),
            ("failed", "Gagal"),
        ],
        string="Status WhatsApp",
        compute="_compute_whatsapp_status",
        store=False,
        help="Status ringkas pengiriman WhatsApp berdasarkan riwayat pesan terakhir.",
    )

    @api.depends(
        "whatsapp_outbox_ids",
        "whatsapp_outbox_ids.is_delivered",
        "whatsapp_outbox_ids.is_queued",
        "whatsapp_outbox_ids.error_msg",
    )
    def _compute_whatsapp_status(self):
        for order in self:
            if not order.whatsapp_outbox_ids:
                order.whatsapp_status = "not_sent"
            else:
                latest = order.whatsapp_outbox_ids.sorted(lambda r: r.id, reverse=True)[:1]
                if latest.is_delivered:
                    order.whatsapp_status = "delivered"
                elif latest.error_msg and not latest.is_delivered:
                    order.whatsapp_status = "failed"
                elif latest.is_queued:
                    order.whatsapp_status = "pending"
                else:
                    order.whatsapp_status = "not_sent"

    def _get_partner_phone(self, partner=None):
        """Ambil nomor telepon partner secara aman baik dari mobile maupun phone."""
        target = partner or self.partner_id
        if not target:
            return ""
        return getattr(target, "mobile", None) or getattr(target, "phone", None) or ""

    @api.onchange("partner_id")
    def _onchange_partner_id_set_whatsapp_phone(self):
        for order in self:
            if order.partner_id and not order.whatsapp_phone:
                raw_phone = order._get_partner_phone()
                if raw_phone:
                    from ..utils.phone_utils import normalize_phone_number
                    order.whatsapp_phone = normalize_phone_number(raw_phone)

    def action_send_whatsapp_notification(self, template_type="invoice", custom_text=None, phone=None, send_immediate=True):
        """
        Kirim notifikasi WhatsApp untuk pesanan laundry ini menggunakan gateway WAPI (infinys.wapi.outbox).

        :param template_type: Pilihan template: 'invoice', 'ready', 'reminder', 'custom'
        :param custom_text: Isi pesan kustom jika template_type == 'custom'
        :param phone: Nomor telepon tujuan alternatif (default menggunakan whatsapp_phone / partner_id)
        :param send_immediate: Jika True, langsung kirim ke WAPI; jika False, biarkan dalam antrean outbox (cron)
        :return: Dict status hasil pengiriman {'success': bool, 'message': str, 'outbox_id': int, 'is_delivered': bool}
        """
        self.ensure_one()

        from ..utils.phone_utils import normalize_phone_number, validate_phone_number
        from ..utils.wa_templates import get_whatsapp_message

        # Tentukan nomor telepon tujuan
        target_phone = phone or self.whatsapp_phone
        if not target_phone and self.partner_id:
            target_phone = self._get_partner_phone()

        # Normalisasi dan validasi nomor telepon
        normalized_phone = normalize_phone_number(target_phone)
        is_valid, err_msg = validate_phone_number(normalized_phone)
        if not is_valid:
            return {
                "success": False,
                "message": f"Pengiriman WhatsApp gagal: {err_msg}",
                "phone": target_phone,
                "outbox_id": False,
                "is_delivered": False,
            }

        # Simpan nomor yang sudah divalidasi ke pesanan jika belum ada
        if not self.whatsapp_phone:
            self.whatsapp_phone = normalized_phone

        # Render pesan menggunakan template builder
        company_name = self.company_id.name if hasattr(self, "company_id") and self.company_id else "LaundryFlow"
        message_body = get_whatsapp_message(
            self,
            template_type=template_type,
            custom_text=custom_text,
            company_name=company_name,
        )

        subject_map = {
            "invoice": f"Nota Pesanan {self.name}",
            "created": f"Nota Pesanan {self.name}",
            "order_created": f"Nota Pesanan {self.name}",
            "ready": f"Pesanan Siap {self.name}",
            "order_ready": f"Pesanan Siap {self.name}",
            "reminder": f"Pengingat Pesanan {self.name}",
            "custom": f"Pesan Laundry {self.name}",
        }
        subject = subject_map.get(template_type, f"Notifikasi Pesanan {self.name}")

        # Buat record outbox di infinys.wapi.outbox
        Outbox = self.env["infinys.wapi.outbox"].sudo()
        outbox_vals = {
            "name": subject,
            "phone": normalized_phone,
            "message": f"<p>{message_body.replace(chr(10), '<br/>')}</p>",
            "is_queued": True,
        }
        outbox = Outbox.create(outbox_vals)

        # Hubungkan outbox dengan pesanan ini
        self.write({"whatsapp_outbox_ids": [(4, outbox.id)]})

        delivered = False
        send_error = None

        if send_immediate:
            try:
                # Kirim langsung via method send_message_immediate
                outbox.send_message_immediate()
                delivered = bool(outbox.is_delivered)
                send_error = outbox.error_msg
            except Exception as e:
                send_error = str(e)
                delivered = False

        if delivered:
            self.write({
                "whatsapp_sent": True,
                "whatsapp_last_sent": fields.Datetime.now(),
            })

        return {
            "success": True if (delivered or not send_immediate or not send_error) else False,
            "message": "Pesan berhasil dikirim" if delivered else (f"Pesan diantrekan: {send_error}" if send_error else "Pesan berhasil masuk antrean"),
            "outbox_id": outbox.id,
            "phone": normalized_phone,
            "is_delivered": delivered,
            "template_used": template_type,
        }

    def _auto_notify_order_ready(self):
        """
        Otomasi pengiriman notifikasi WhatsApp saat pesanan menjadi 'ready' (Event 2).
        """
        auto_send_param = self.env["ir.config_parameter"].sudo()
        auto_send_enabled = True
        if hasattr(auto_send_param, "get_bool"):
            auto_send_enabled = auto_send_param.get_bool("laundry.auto_send_whatsapp_on_ready", default=True)
        elif hasattr(auto_send_param, "get_param"):
            val = auto_send_param.get_param("laundry.auto_send_whatsapp_on_ready", "True")
            auto_send_enabled = str(val).lower() in ("true", "1", "t", "yes")

        skip_notification = self.env.context.get("skip_whatsapp_notification", False)
        if not auto_send_enabled or skip_notification:
            return

        import logging
        _logger = logging.getLogger(__name__)

        for order in self:
            if order.whatsapp_phone or order._get_partner_phone():
                try:
                    order.action_send_whatsapp_notification(template_type="ready", send_immediate=True)
                except Exception as e:
                    _logger.warning("Gagal mengirimkan notifikasi WhatsApp otomatis saat order %s ready: %s", order.name, e)

    # -------------------------------------------------------------------------
    # Konfigurasi Same Day Service (Ketentuan 3, 7, 8)
    # -------------------------------------------------------------------------
    @api.model
    def is_same_day_available(self):
        """
        Mengecek apakah Same Day Service sedang dibuka oleh admin/operasional.
        Default: True.
        """
        param_obj = self.env["ir.config_parameter"].sudo()
        if hasattr(param_obj, "get_bool"):
            return param_obj.get_bool("laundry.same_day_available", default=True)
        elif hasattr(param_obj, "get_param"):
            val = param_obj.get_param("laundry.same_day_available", "True")
        else:
            rec = param_obj.search([("key", "=", "laundry.same_day_available")], limit=1)
            val = rec.value if rec else "True"
        return str(val).lower() in ("true", "1", "t", "yes")

    @api.model
    def get_same_day_surcharge(self):
        """
        Mengambil tarif biaya tambahan Same Day Service dari konfigurasi Odoo.
        Ketentuan 7 & 8:
        - Jangan menambahkan biaya tambahan sebelum tarif dikonfirmasi.
        - Jika biaya tambahan tersedia, ambil dari konfigurasi Odoo.
        Default: 0.0 jika belum ada tarif yang dikonfirmasi.
        """
        param_obj = self.env["ir.config_parameter"].sudo()
        if hasattr(param_obj, "get_float"):
            return param_obj.get_float("laundry.same_day_surcharge", default=0.0)
        elif hasattr(param_obj, "get_param"):
            val = param_obj.get_param("laundry.same_day_surcharge", 0.0)
        else:
            rec = param_obj.search([("key", "=", "laundry.same_day_surcharge")], limit=1)
            val = rec.value if rec else 0.0
        try:
            return float(val)
        except (ValueError, TypeError):
            return 0.0

    @api.model
    def set_same_day_config(self, available=True, surcharge=0.0):
        """
        Helper method untuk admin mengonfigurasi ketersediaan dan biaya Same Day Service.
        """
        param_obj = self.env["ir.config_parameter"].sudo()
        if hasattr(param_obj, "set_bool"):
            param_obj.set_bool("laundry.same_day_available", bool(available))
        elif hasattr(param_obj, "set_param"):
            param_obj.set_param("laundry.same_day_available", str(bool(available)))
        else:
            rec = param_obj.search([("key", "=", "laundry.same_day_available")], limit=1)
            if rec:
                rec.value = str(bool(available))
            else:
                param_obj.create({"key": "laundry.same_day_available", "value": str(bool(available))})

        if hasattr(param_obj, "set_float"):
            param_obj.set_float("laundry.same_day_surcharge", float(surcharge))
        elif hasattr(param_obj, "set_param"):
            param_obj.set_param("laundry.same_day_surcharge", str(float(surcharge)))
        else:
            rec = param_obj.search([("key", "=", "laundry.same_day_surcharge")], limit=1)
            if rec:
                rec.value = str(float(surcharge))
            else:
                param_obj.create({"key": "laundry.same_day_surcharge", "value": str(float(surcharge))})
        return True

    @api.model
    def get_available_service_speeds(self):
        """
        Mengembalikan opsi kecepatan pengerjaan untuk aplikasi klien (Flutter).
        Ketentuan 1, 3, 4, 6:
        - Pelanggan dapat memilih Reguler atau Same Day.
        - Flutter menampilkan pilihan yang tersedia berdasarkan status ketersediaan saat ini.
        - Tanpa menjanjikan estimasi waktu selesai fiktif jika aturan operasional belum ditentukan.
        """
        same_day_active = self.is_same_day_available()
        surcharge = self.get_same_day_surcharge() if same_day_active else 0.0
        return [
            {
                "code": "regular",
                "name": "Reguler",
                "available": True,
                "fee": 0.0,
                "description": "Pengerjaan standar reguler",
            },
            {
                "code": "same_day",
                "name": "Same Day Service",
                "available": same_day_active,
                "fee": surcharge,
                "description": "Pengerjaan prioritas selesai di hari yang sama",
            },
        ]

    # -------------------------------------------------------------------------
    # Perhitungan Total & Berat (Ketentuan 5, 9, 10)
    # -------------------------------------------------------------------------
    @api.depends("line_ids.subtotal", "service_speed_fee", "delivery_fee", "weight", "price_per_kg")
    def _compute_total_amount(self):
        for order in self:
            speed_fee = order.service_speed_fee or 0.0
            deliv_fee = order.delivery_fee or 0.0
            if order.line_ids:
                order.total_amount = sum(order.line_ids.mapped("subtotal")) + speed_fee + deliv_fee
            else:
                # Kompatibilitas mundur dengan transaksi legacy tunggal
                order.total_amount = ((order.weight or 0.0) * (order.price_per_kg or 0.0)) + speed_fee + deliv_fee

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

    @api.constrains("service_speed")
    def _check_service_speed_selection(self):
        for order in self:
            if order.service_speed not in ("regular", "same_day"):
                raise ValidationError(_(
                    "Pilihan jenis pengerjaan '%(speed)s' tidak valid. "
                    "Pilihan yang tersedia: Reguler (regular) atau Same Day Service (same_day).",
                    speed=order.service_speed,
                ))

    @api.model_create_multi
    def create(self, vals_list):
        sequence = self.env["ir.sequence"]
        for vals in vals_list:
            if vals.get("name", "New") == "New":
                vals["name"] = sequence.next_by_code("laundry.order") or "New"

            # Validasi jenis pengerjaan (Ketentuan 1, 2, 5)
            speed = vals.get("service_speed", "regular")
            if speed not in ("regular", "same_day"):
                raise ValidationError(_(
                    "Pilihan jenis pengerjaan '%(speed)s' tidak valid. "
                    "Pilihan yang tersedia: Reguler (regular) atau Same Day Service (same_day).",
                    speed=speed,
                ))

            if speed == "same_day":
                if not self.is_same_day_available():
                    raise ValidationError(_("Layanan Same Day Service sedang tidak tersedia saat ini."))
                # Snapshot tarif biaya tambahan dari konfigurasi Odoo (Ketentuan 7, 8, 9)
                if "service_speed_fee" not in vals or vals.get("service_speed_fee") is None:
                    vals["service_speed_fee"] = self.get_same_day_surcharge()
            elif speed == "regular":
                if "service_speed_fee" not in vals or vals.get("service_speed_fee") is None:
                    vals["service_speed_fee"] = 0.0

            # Backend menghitung ulang: jangan mempercayai total_amount dari payload klien
            if "total_amount" in vals and ("line_ids" in vals or vals.get("line_ids")):
                vals.pop("total_amount", None)

            # Auto-populate whatsapp_phone dari partner jika belum diisi
            if vals.get("partner_id") and not vals.get("whatsapp_phone"):
                partner = self.env["res.partner"].browse(vals["partner_id"])
                raw_phone = getattr(partner, "mobile", None) or getattr(partner, "phone", None) or ""
                if raw_phone:
                    from ..utils.phone_utils import normalize_phone_number
                    vals["whatsapp_phone"] = normalize_phone_number(raw_phone)

        orders = super().create(vals_list)
        for order in orders:
            order._compute_weight()
            order._compute_total_amount()

        # Otomasi pengiriman WhatsApp saat pesanan baru dibuat (Event 1)
        auto_send_param = self.env["ir.config_parameter"].sudo()
        auto_send_enabled = True
        if hasattr(auto_send_param, "get_bool"):
            auto_send_enabled = auto_send_param.get_bool("laundry.auto_send_whatsapp_on_create", default=True)
        elif hasattr(auto_send_param, "get_param"):
            val = auto_send_param.get_param("laundry.auto_send_whatsapp_on_create", "True")
            auto_send_enabled = str(val).lower() in ("true", "1", "t", "yes")

        skip_notification = self.env.context.get("skip_whatsapp_notification", False)

        if auto_send_enabled and not skip_notification:
            import logging
            _logger = logging.getLogger(__name__)
            for order in orders:
                if order.whatsapp_phone or order._get_partner_phone():
                    try:
                        order.action_send_whatsapp_notification(template_type="invoice", send_immediate=True)
                    except Exception as e:
                        _logger.warning("Gagal mengirimkan notifikasi WhatsApp otomatis saat pembuatan order %s: %s", order.name, e)

        return orders

    def write(self, vals):
        if "service_speed" in vals:
            speed = vals.get("service_speed")
            if speed not in ("regular", "same_day"):
                raise ValidationError(_(
                    "Pilihan jenis pengerjaan '%(speed)s' tidak valid. "
                    "Pilihan yang tersedia: Reguler (regular) atau Same Day Service (same_day).",
                    speed=speed,
                ))
            if speed == "same_day":
                for order in self:
                    # Validasi ketersediaan hanya jika pesanan sebelumnya bukan same_day
                    if order.service_speed != "same_day" and not self.is_same_day_available():
                        raise ValidationError(_("Layanan Same Day Service sedang tidak tersedia saat ini."))
                if "service_speed_fee" not in vals:
                    vals["service_speed_fee"] = self.get_same_day_surcharge()
            elif speed == "regular":
                if "service_speed_fee" not in vals:
                    vals["service_speed_fee"] = 0.0

        orders_to_notify_ready = self.env["laundry.order"]
        if "state" in vals:
            new_state = vals.get("state")
            for order in self:
                order._check_state_transition(new_state)
            if new_state == "ready":
                orders_to_notify_ready = self.filtered(lambda o: o.state != "ready")

        res = super().write(vals)
        if "service_speed" in vals or "service_speed_fee" in vals:
            for order in self:
                order._compute_total_amount()

        if orders_to_notify_ready:
            orders_to_notify_ready._auto_notify_order_ready()

        return res

    def recompute_prices(self):
        """
        Memaksa backend menghitung ulang semua subtotal dan total harga pesanan.
        Perubahan konfigurasi tidak boleh mengubah order lama (Ketentuan 10).
        """
        for order in self:
            order.line_ids._compute_subtotal()
            order._compute_weight()
            order._compute_total_amount()
        return True

    # -------------------------------------------------------------------------
    # Alur Kerja & Transisi Status Pesanan (Order Workflow - Task 1)
    # -------------------------------------------------------------------------
    def _get_process_pipeline(self):
        """
        Menentukan tahapan proses wajib untuk pesanan ini berdasarkan layanan yang dipesan.
        Mengembalikan daftar tahapan di antara 'received' dan 'ready'.

        Aturan Bisnis:
        - Setrika Saja: ['ironing'] (tidak boleh dipaksa washing dan drying)
        - Cuci Lipat: ['washing', 'drying'] (tidak perlu ironing)
        - Cuci Setrika / Cuci Standar: ['washing', 'drying', 'ironing']
        - Karpet / Bantal / Guling: ['washing', 'drying'] (tidak perlu ironing)
        - Campuran: Menggabungkan seluruh tahapan wajib dari setiap item
        """
        self.ensure_one()
        if self.line_ids:
            needs_washing = False
            needs_ironing = False

            for line in self.line_ids:
                prod_name = (line.product_template_id.name or "").strip().lower()

                # Setrika Saja: hanya setrika (tidak cuci)
                is_iron_only = ("setrika" in prod_name or "iron" in prod_name) and not any(
                    w in prod_name for w in ["cuci", "wash", "clean"]
                )

                # Layanan tanpa setrika: cuci lipat, karpet, bantal, guling
                is_no_iron = (
                    "cuci lipat" in prod_name or
                    "lipat" in prod_name or
                    "karpet" in prod_name or
                    "carpet" in prod_name or
                    "bantal" in prod_name or
                    "guling" in prod_name
                )

                if is_iron_only:
                    needs_ironing = True
                elif is_no_iron:
                    needs_washing = True
                else:
                    # Cuci setrika, cuci kiloan, cuci satuan, dry cleaning, sprei, bed cover, selimut
                    needs_washing = True
                    needs_ironing = True

            stages = []
            if needs_washing:
                stages.append("washing")
                stages.append("drying")  # setiap yang dicuci wajib dikeringkan
            if needs_ironing:
                stages.append("ironing")
            return stages if stages else ["washing", "drying", "ironing"]

        # Kompatibilitas mundur pesanan lama (legacy tanpa line_ids)
        service_type = self.service_type or "wash_iron"
        if service_type == "iron":
            return ["ironing"]
        elif service_type == "wash_fold":
            return ["washing", "drying"]
        else:
            return ["washing", "drying", "ironing"]

    def _check_state_transition(self, new_state):
        """
        Memvalidasi apakah transisi dari self.state ke new_state sah sesuai
        aturan workflow, jenis layanan, dan metode penyerahan (pickup vs delivery).
        """
        self.ensure_one()
        current_state = self.state

        # Pesanan cancelled tidak boleh diproses kembali tanpa aturan bisnis yang jelas
        if current_state == "cancelled":
            raise ValidationError(
                _("Pesanan '%(name)s' sudah dalam status dibatalkan dan tidak dapat diproses kembali.", name=self.name)
            )

        # Pesanan completed tidak dapat diubah statusnya
        if current_state == "completed":
            raise ValidationError(
                _("Pesanan '%(name)s' sudah selesai (completed) dan tidak dapat diubah statusnya.", name=self.name)
            )

        # Jika status sama, tidak ada perubahan
        if current_state == new_state:
            return True

        # Pembatalan diizinkan dari status apapun selama belum selesai atau dibatalkan
        if new_state == "cancelled":
            return True

        pipeline = self._get_process_pipeline()
        delivery = self.delivery_type or "pickup"

        if new_state == "washing":
            if "washing" not in pipeline:
                raise ValidationError(
                    _("Layanan pada pesanan '%(name)s' (misal: Setrika Saja) tidak memerlukan tahapan pencucian (washing).",
                      name=self.name)
                )
            if current_state != "received":
                raise ValidationError(
                    _("Pesanan '%(name)s' hanya dapat dipindahkan ke status 'Sedang Dicuci' (washing) dari status 'Diterima' (received). Status saat ini: '%(cur)s'.",
                      name=self.name, cur=current_state)
                )

        elif new_state == "drying":
            if "drying" not in pipeline:
                raise ValidationError(
                    _("Layanan pada pesanan '%(name)s' tidak memerlukan tahapan pengeringan (drying).", name=self.name)
                )
            if current_state != "washing":
                if current_state == "received":
                    raise ValidationError(
                        _("Pesanan '%(name)s' tidak boleh melompati tahapan wajib: harus melalui proses pencucian (washing) terlebih dahulu sebelum dikeringkan.",
                          name=self.name)
                    )
                raise ValidationError(
                    _("Pesanan '%(name)s' hanya dapat dipindahkan ke status 'Sedang Dikeringkan' (drying) dari status 'Sedang Dicuci' (washing). Status saat ini: '%(cur)s'.",
                      name=self.name, cur=current_state)
                )

        elif new_state == "ironing":
            if "ironing" not in pipeline:
                raise ValidationError(
                    _("Layanan pada pesanan '%(name)s' (misal: Cuci Lipat) tidak memerlukan tahapan penyetrikaan (ironing).",
                      name=self.name)
                )
            expected_prev = "drying" if "drying" in pipeline else "received"
            if current_state != expected_prev:
                if expected_prev == "drying":
                    raise ValidationError(
                        _("Pesanan '%(name)s' tidak boleh melompati tahapan wajib: harus melalui proses pencucian dan pengeringan sebelum disetrika. Status saat ini: '%(cur)s'.",
                          name=self.name, cur=current_state)
                    )
                else:
                    raise ValidationError(
                        _("Pesanan Setrika Saja '%(name)s' hanya dapat disetrika langsung dari status 'Diterima' (received). Status saat ini: '%(cur)s'.",
                          name=self.name, cur=current_state)
                    )

        elif new_state == "ready":
            last_stage = pipeline[-1] if pipeline else "received"
            if current_state != last_stage:
                stage_labels = {
                    "washing": "Pencucian (washing)",
                    "drying": "Pengeringan (drying)",
                    "ironing": "Penyetrikaan (ironing)",
                    "received": "Diterima (received)",
                }
                expected_label = stage_labels.get(last_stage, last_stage)
                raise ValidationError(
                    _("Pesanan '%(name)s' tidak boleh melompati tahapan wajib: harus menyelesaikan tahapan %(stage)s terlebih dahulu sebelum siap diambil/dikirim. Status saat ini: '%(cur)s'.",
                      name=self.name, stage=expected_label, cur=current_state)
                )

        elif new_state == "out_for_delivery":
            if delivery != "delivery":
                raise ValidationError(
                    _("Pesanan '%(name)s' menggunakan metode ambil sendiri di tempat (pickup), sehingga tidak melalui proses pengiriman kurir (out_for_delivery).",
                      name=self.name)
                )
            if current_state != "ready":
                raise ValidationError(
                    _("Pesanan '%(name)s' harus berstatus 'Siap Diambil / Siap Kirim' (ready) sebelum dapat dikirimkan ke pelanggan. Status saat ini: '%(cur)s'.",
                      name=self.name, cur=current_state)
                )

        elif new_state == "completed":
            if delivery == "delivery":
                if current_state != "out_for_delivery":
                    if current_state == "ready":
                        raise ValidationError(
                            _("Pesanan antar (delivery) '%(name)s' tidak boleh langsung diselesaikan: harus melewati status 'Dalam Pengiriman' (out_for_delivery) sebelum 'Selesai' (completed).",
                              name=self.name)
                        )
                    raise ValidationError(
                        _("Pesanan antar (delivery) '%(name)s' hanya dapat diselesaikan setelah melalui proses pengiriman (out_for_delivery). Status saat ini: '%(cur)s'.",
                          name=self.name, cur=current_state)
                    )
            else:
                if current_state != "ready":
                    raise ValidationError(
                        _("Pesanan ambil di tempat (pickup) '%(name)s' harus berstatus 'Siap Diambil' (ready) sebelum dapat diselesaikan. Status saat ini: '%(cur)s'.",
                          name=self.name, cur=current_state)
                    )

        return True

    def action_washing(self):
        """Memindahkan pesanan ke proses pencucian (washing)."""
        for order in self:
            order._check_state_transition("washing")
            order.state = "washing"
        return True

    def action_drying(self):
        """Memindahkan pesanan ke proses pengeringan (drying)."""
        for order in self:
            order._check_state_transition("drying")
            order.state = "drying"
        return True

    def action_ironing(self):
        """Memindahkan pesanan ke proses penyetrikaan (ironing)."""
        for order in self:
            order._check_state_transition("ironing")
            order.state = "ironing"
        return True

    def action_ready(self):
        """Menandai pesanan telah selesai dikerjakan dan siap diambil atau dikirim."""
        for order in self:
            order._check_state_transition("ready")
            order.write({"state": "ready"})
        return True

    def action_out_for_delivery(self):
        """Memindahkan pesanan layanan delivery ke status dalam pengiriman kurir."""
        for order in self:
            order._check_state_transition("out_for_delivery")
            order.state = "out_for_delivery"
        return True

    def action_complete(self):
        """Menyelesaikan transaksi pesanan laundry (pakaian telah diterima pelanggan)."""
        for order in self:
            order._check_state_transition("completed")
            order.state = "completed"
        return True

    def action_cancel(self):
        """Membatalkan pesanan laundry."""
        for order in self:
            order._check_state_transition("cancelled")
            order.state = "cancelled"
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
