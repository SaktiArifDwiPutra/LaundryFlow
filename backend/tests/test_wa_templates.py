# -*- coding: utf-8 -*-
import unittest
from ..utils.wa_templates import (
    build_order_created_message,
    build_order_ready_message,
    build_order_reminder_message,
    build_custom_order_message,
    get_whatsapp_message,
)
from ..utils.wa_formatter import (
    wa_bold,
    wa_italic,
    wa_strike,
    wa_monospace,
    wa_bullet,
    format_currency_idr,
    format_datetime_id,
    clean_whatsapp_text,
)


class TestWhatsAppTemplates(unittest.TestCase):
    """
    Unit test suite untuk rendering template pesan WhatsApp LaundryFlow.
    Menguji nota pesanan baru, pesan siap diambil/diantar, reminder, custom message,
    serta helper formatter WhatsApp.
    """

    def setUp(self):
        super().setUp()
        self.sample_order = {
            "name": "LND/2026/00015",
            "partner_id": {"name": "Sakti Arif Dwi Putra"},
            "order_date": "2026-11-06 09:30:00",
            "service_speed": "same_day",
            "delivery_type": "pickup",
            "total_amount": 75000.0,
            "line_ids": [
                {"name": "Cuci dan Setrika", "quantity": 5.0, "uom_id": {"name": "kg"}, "subtotal": 50000.0},
                {"name": "Surcharge Express", "quantity": 1.0, "uom_id": {"name": "Unit"}, "subtotal": 25000.0},
            ],
            "item_details": "5 Kemeja, 3 Celana Bahan",
            "notes": "Harap pisahkan pakaian warna putih",
        }

    def test_01_wa_formatter_helpers(self):
        """Uji seluruh helper pemformatan teks WhatsApp."""
        self.assertEqual(wa_bold("Halo"), "*Halo*")
        self.assertEqual(wa_italic("Penting"), "_Penting_")
        self.assertEqual(wa_strike("Diskon"), "~Diskon~")
        self.assertEqual(wa_monospace("CODE123"), "```CODE123```")
        self.assertEqual(wa_bullet("Cuci Kiloan"), "• Cuci Kiloan")
        self.assertEqual(format_currency_idr(50000), "Rp 50.000")
        self.assertEqual(format_currency_idr(1250000), "Rp 1.250.000")
        self.assertEqual(format_currency_idr(0), "Rp 0")
        self.assertEqual(format_datetime_id("2026-11-06 14:30:00"), "06 Nov 2026, 14:30 WIB")
        self.assertEqual(clean_whatsapp_text("Line 1\r\n\r\n\r\nLine 2"), "Line 1\n\nLine 2")

    def test_02_order_created_full_template(self):
        """Uji template nota pesanan baru dengan data lengkap."""
        msg = build_order_created_message(self.sample_order, company_name="LaundryFlow")
        self.assertIn("LAUNDRYFLOW — NOTA PESANAN", msg)
        self.assertIn("LND/2026/00015", msg)
        self.assertIn("Sakti Arif Dwi Putra", msg)
        self.assertIn("06 Nov 2026, 09:30 WIB", msg)
        self.assertIn("Same Day Service (Express)", msg)
        self.assertIn("Ambil di Tempat (Pickup)", msg)
        self.assertIn("Cuci dan Setrika (5 kg): Rp 50.000", msg)
        self.assertIn("5 Kemeja, 3 Celana Bahan", msg)
        self.assertIn("Rp 75.000", msg)
        self.assertIn("Harap pisahkan pakaian warna putih", msg)

    def test_03_order_created_minimal_template(self):
        """Uji template nota pesanan baru dengan data minimal."""
        minimal_order = {
            "name": "LND/2026/00016",
            "partner_id": None,
            "order_date": "2026-11-06 10:00:00",
            "service_speed": "regular",
            "delivery_type": "delivery",
            "total_amount": 20000.0,
            "line_ids": [],
            "item_details": False,
            "notes": False,
        }
        msg = build_order_created_message(minimal_order, company_name="LaundryFlow")
        self.assertIn("LND/2026/00016", msg)
        self.assertIn("Pelanggan", msg)
        self.assertIn("Layanan Reguler", msg)
        self.assertIn("Diantar ke Alamat (Delivery)", msg)
        self.assertIn("Rp 20.000", msg)

    def test_04_order_ready_pickup_template(self):
        """Uji template notifikasi pesanan siap untuk metode pickup."""
        msg = build_order_ready_message(self.sample_order, company_name="LaundryFlow")
        self.assertIn("PESANAN SIAP!", msg)
        self.assertIn("Siap Diambil di Outlet (Pickup)", msg)
        self.assertIn("LND/2026/00015", msg)
        self.assertIn("Rp 75.000", msg)
        self.assertIn("Harap tunjukkan nomor pesanan ini", msg)

    def test_05_order_ready_delivery_template(self):
        """Uji template notifikasi pesanan siap untuk metode delivery."""
        delivery_order = dict(self.sample_order, delivery_type="delivery")
        msg = build_order_ready_message(delivery_order, company_name="LaundryFlow")
        self.assertIn("PESANAN SIAP!", msg)
        self.assertIn("Siap Diantar (Delivery)", msg)
        self.assertIn("kurir", msg)
        self.assertIn("Pastikan nomor ini aktif", msg)

    def test_06_order_reminder_template(self):
        """Uji template notifikasi pengingat pengambilan pesanan."""
        msg = build_order_reminder_message(self.sample_order, company_name="LaundryFlow", days_unclaimed=4)
        self.assertIn("PENGINGAT PESANAN", msg)
        self.assertIn("LND/2026/00015", msg)
        self.assertIn("4 hari", msg)
        self.assertIn("Rp 75.000", msg)

    def test_07_custom_message_template(self):
        """Uji pembungkusan pesan kustom dengan konteks toko & order."""
        custom_body = "Pakaian sprei Anda membutuhkan waktu pengeringan ekstra 1 jam."
        msg = build_custom_order_message(self.sample_order, custom_body, company_name="LaundryFlow")
        self.assertIn("LAUNDRYFLOW", msg)
        self.assertIn("LND/2026/00015", msg)
        self.assertIn(custom_body, msg)

    def test_08_master_dispatcher(self):
        """Uji fungsi dispatcher get_whatsapp_message untuk berbagai template_type."""
        # invoice
        self.assertIn("NOTA PESANAN", get_whatsapp_message(self.sample_order, template_type="invoice"))
        self.assertIn("NOTA PESANAN", get_whatsapp_message(self.sample_order, template_type="created"))
        # ready
        self.assertIn("PESANAN SIAP", get_whatsapp_message(self.sample_order, template_type="ready"))
        # reminder
        self.assertIn("PENGINGAT PESANAN", get_whatsapp_message(self.sample_order, template_type="reminder"))
        # custom
        self.assertIn("Tes Pesan", get_whatsapp_message(self.sample_order, template_type="custom", custom_text="Tes Pesan"))
        # unknown fallback -> invoice
        self.assertIn("NOTA PESANAN", get_whatsapp_message(self.sample_order, template_type="unknown_type"))

    def test_09_none_or_empty_handling(self):
        """Uji penanganan saat input order bernilai None."""
        self.assertEqual(build_order_created_message(None), "")
        self.assertEqual(build_order_ready_message(None), "")
        self.assertEqual(build_order_reminder_message(None), "")
        self.assertEqual(build_custom_order_message(None, "Halo"), "Halo")
