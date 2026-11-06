# -*- coding: utf-8 -*-
try:
    from .wa_formatter import (
        wa_bold,
        wa_italic,
        wa_bullet,
        format_currency_idr,
        format_datetime_id,
        clean_whatsapp_text,
    )
except ImportError:
    from wa_formatter import (
        wa_bold,
        wa_italic,
        wa_bullet,
        format_currency_idr,
        format_datetime_id,
        clean_whatsapp_text,
    )


def _get_field(record, field_name, default=None):
    """Safe getter that works on both Odoo ORM records and Python dictionaries."""
    if isinstance(record, dict):
        return record.get(field_name, default)
    return getattr(record, field_name, default)


def build_order_created_message(order, company_name=None):
    """
    Build a structured WhatsApp message for a newly created Laundry Order / Digital Invoice.

    :param order: laundry.order record or dict representation
    :param company_name: Store/company name header (default: from order.company_id or 'LaundryFlow')
    :return: Formatted WhatsApp message string
    """
    if not order:
        return ''

    # Company name
    if not company_name:
        company_rec = _get_field(order, 'company_id')
        company_name = _get_field(company_rec, 'name') if company_rec else 'LaundryFlow'

    # Customer name
    partner = _get_field(order, 'partner_id')
    customer_name = (_get_field(partner, 'name') if partner else None) or 'Pelanggan'

    # Order attributes
    order_number = _get_field(order, 'name') or 'Draft'
    order_date = _get_field(order, 'order_date')
    order_date_str = format_datetime_id(order_date)

    # Service speed
    speed = _get_field(order, 'service_speed') or 'regular'
    speed_label = "Same Day Service (Express)" if speed == 'same_day' else "Layanan Reguler"

    # Delivery type
    del_type = _get_field(order, 'delivery_type') or 'pickup'
    del_label = "Diantar ke Alamat (Delivery)" if del_type == 'delivery' else "Ambil di Tempat (Pickup)"

    # Total amount
    total_amount = _get_field(order, 'total_amount') or 0.0
    total_str = format_currency_idr(total_amount)

    # Item details / notes
    item_details = _get_field(order, 'item_details')
    notes = _get_field(order, 'notes')

    # Build Lines
    lines = []
    lines.append(f"🧺 *{company_name.upper()} — NOTA PESANAN*")
    lines.append("=" * 36)
    lines.append(f"Halo *{customer_name}*, terima kasih telah mencuci di *{company_name}*! Pesanan Anda telah kami terima.")
    lines.append("")
    lines.append("📋 *Rincian Pesanan:*")
    lines.append(f"• No. Pesanan: *{order_number}*")
    lines.append(f"• Tanggal: {order_date_str}")
    lines.append(f"• Kecepatan: {speed_label}")
    lines.append(f"• Penyerahan: {del_label}")
    lines.append("")

    # Order details (line items)
    order_lines = _get_field(order, 'line_ids') or []
    if order_lines:
        lines.append("🏷️ *Detail Layanan:*")
        for line in order_lines:
            prod_tmpl = _get_field(line, 'product_template_id')
            prod_name = (_get_field(prod_tmpl, 'name') if prod_tmpl else None) or _get_field(line, 'name') or 'Layanan'
            qty = _get_field(line, 'quantity') or _get_field(line, 'product_uom_qty') or 1.0
            uom = _get_field(line, 'uom_id')
            uom_name = (_get_field(uom, 'name') if uom else None) or 'Unit'
            subtotal = _get_field(line, 'subtotal') or _get_field(line, 'price_subtotal') or 0.0
            subtotal_str = format_currency_idr(subtotal)

            qty_str = f"{qty:g}" if isinstance(qty, (int, float)) else str(qty)
            lines.append(f"• {prod_name} ({qty_str} {uom_name}): {subtotal_str}")
        lines.append("")

    if item_details and str(item_details).strip():
        lines.append(f"👕 *Rincian Pakaian:* {str(item_details).strip()}")
        lines.append("")

    lines.append(f"💰 *Total Biaya:* *{total_str}*")

    if notes and str(notes).strip():
        lines.append(f"📝 *Catatan:* _{str(notes).strip()}_")

    lines.append("")
    lines.append("Pakaian Anda sedang dalam penanganan proses kami. Kami akan mengirimkan notifikasi saat pakaian siap diambil/diantar.")
    lines.append("")
    lines.append("Terima kasih atas kepercayaan Anda! ✨")

    return clean_whatsapp_text("\n".join(lines))


def build_order_ready_message(order, company_name=None):
    """
    Build a WhatsApp notification message when a Laundry Order is ready for pickup or delivery.

    :param order: laundry.order record or dict representation
    :param company_name: Store/company name header (default: from order.company_id or 'LaundryFlow')
    :return: Formatted WhatsApp message string
    """
    if not order:
        return ''

    # Company name
    if not company_name:
        company_rec = _get_field(order, 'company_id')
        company_name = _get_field(company_rec, 'name') if company_rec else 'LaundryFlow'

    # Customer name
    partner = _get_field(order, 'partner_id')
    customer_name = (_get_field(partner, 'name') if partner else None) or 'Pelanggan'

    # Order attributes
    order_number = _get_field(order, 'name') or 'Pesanan'
    del_type = _get_field(order, 'delivery_type') or 'pickup'
    total_amount = _get_field(order, 'total_amount') or 0.0
    total_str = format_currency_idr(total_amount)

    lines = []
    lines.append(f"✨ *{company_name.upper()} — PESANAN SIAP!* ✨")
    lines.append("=" * 36)
    lines.append(f"Kabar gembira untuk *{customer_name}*! 🎉")
    lines.append(f"Pakaian Anda dengan nomor pesanan *{order_number}* sudah selesai diproses, bersih, harum, dan siap!")
    lines.append("")

    if del_type == 'pickup':
        lines.append("🏪 *Status: Siap Diambil di Outlet (Pickup)*")
        lines.append(f"Silakan datang ke outlet *{company_name}* untuk mengambil cucian Anda.")
        lines.append(f"• No. Pesanan : *{order_number}*")
        lines.append(f"• Total Biaya : *{total_str}*")
        lines.append("")
        lines.append("Harap tunjukkan nomor pesanan ini kepada staf kami saat pengambilan.")
    else:  # delivery
        lines.append("🛵 *Status: Siap Diantar (Delivery)*")
        lines.append("Cucian Anda telah selesai dipacking rapi dan sedang menunggu jadwal kurir untuk diantar ke alamat Anda.")
        lines.append(f"• No. Pesanan : *{order_number}*")
        lines.append(f"• Total Biaya : *{total_str}*")
        lines.append("")
        lines.append("Pastikan nomor ini aktif agar kurir kami dapat menghubungi saat tiba di lokasi.")

    lines.append("")
    lines.append("Terima kasih telah mempercayakan pakaian Anda kepada kami! Semoga hari Anda menyenangkan. 😊✨")

    return clean_whatsapp_text("\n".join(lines))
