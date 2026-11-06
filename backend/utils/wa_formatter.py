# -*- coding: utf-8 -*-
import re
from datetime import datetime


def wa_bold(text):
    """Wrap text in WhatsApp bold syntax: *text*"""
    if not text:
        return ''
    return f"*{str(text).strip()}*"


def wa_italic(text):
    """Wrap text in WhatsApp italic syntax: _text_"""
    if not text:
        return ''
    return f"_{str(text).strip()}_"


def wa_strike(text):
    """Wrap text in WhatsApp strikethrough syntax: ~text~"""
    if not text:
        return ''
    return f"~{str(text).strip()}~"


def wa_monospace(text):
    """Wrap text in WhatsApp monospace code syntax: ```text```"""
    if not text:
        return ''
    return f"```{str(text).strip()}```"


def wa_bullet(item):
    """Format an item as a WhatsApp bullet point."""
    if not item:
        return ''
    return f"• {str(item).strip()}"


def format_currency_idr(amount):
    """
    Format a numeric amount into Indonesian Rupiah format.
    Example: 25000 -> 'Rp 25.000', 1250500.5 -> 'Rp 1.250.500'
    """
    if amount is None or amount is False:
        return 'Rp 0'
    try:
        val = float(amount)
        # Format with dot as thousands separator
        formatted = f"{int(round(val)):,}".replace(',', '.')
        return f"Rp {formatted}"
    except (ValueError, TypeError):
        return 'Rp 0'


def format_datetime_id(dt, include_time=True):
    """
    Format a datetime object or ISO string into Indonesian standard readable format.
    Example: '06 Nov 2026, 14:30 WIB' or '06 Nov 2026'
    """
    if not dt:
        return '-'

    if isinstance(dt, str):
        # Parse standard Odoo datetime 'YYYY-MM-DD HH:MM:SS' or ISO
        try:
            cleaned_str = dt.replace('T', ' ').split('.')[0]
            if len(cleaned_str) == 10:
                dt = datetime.strptime(cleaned_str, '%Y-%m-%d')
                include_time = False
            else:
                dt = datetime.strptime(cleaned_str, '%Y-%m-%d %H:%M:%S')
        except ValueError:
            return str(dt)

    months_id = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ]

    day = dt.day
    month = months_id[dt.month]
    year = dt.year

    if include_time:
        time_str = dt.strftime('%H:%M')
        return f"{day:02d} {month} {year}, {time_str} WIB"
    return f"{day:02d} {month} {year}"


def clean_whatsapp_text(text):
    """
    Clean text for WhatsApp:
    - Normalizes line breaks to '\n'
    - Removes consecutive empty lines (more than 2)
    - Strips leading and trailing whitespace
    """
    if not text:
        return ''
    # Convert CRLF to LF
    text = str(text).replace('\r\n', '\n').replace('\r', '\n')
    # Collapse 3 or more newlines into 2 newlines
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()

