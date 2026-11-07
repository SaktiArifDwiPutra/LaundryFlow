# -*- coding: utf-8 -*-
import re


def sanitize_country_code(country_code='62'):
    """
    Sanitize country code input (e.g. '+62' -> '62', '0062' -> '62').
    Defaults to '62' if invalid or empty.
    """
    if not country_code:
        return '62'
    code = re.sub(r'\D', '', str(country_code)).lstrip('0')
    return code if code else '62'


def normalize_phone_number(phone, default_country_code='62'):
    """
    Normalize phone number into international format without '+' prefix (e.g., 628978890178).
    Specifically tailored for Indonesian numbers and general international phone numbers.

    Examples:
        - '0897-8890-178'  -> '628978890178'
        - '+62 897 8890 178' -> '628978890178'
        - '628978890178'   -> '628978890178'
        - '8978890178'     -> '628978890178'
        - '00628978890178' -> '628978890178'

    :param phone: String or raw phone number from user/customer record
    :param default_country_code: Default country prefix if number starts with '0' or without country code (default '62')
    :return: Normalized digits string or empty string if input is invalid/empty
    """
    if not phone:
        return ''

    # Convert to string and strip spaces
    phone_str = str(phone).strip()
    if not phone_str:
        return ''

    default_code = sanitize_country_code(default_country_code)

    # Remove all non-digit characters except leading '+' if present
    cleaned = re.sub(r'[^\d+]', '', phone_str)

    # Handle leading '+'
    if cleaned.startswith('+'):
        cleaned = cleaned[1:]

    # Handle double zero prefix '00' (international exit code, e.g. 0062...)
    if cleaned.startswith('00'):
        cleaned = cleaned[2:]

    # Indonesian & local prefixes handling
    if cleaned.startswith('0'):
        # e.g., 08123456789 -> 628123456789
        cleaned = default_code + cleaned[1:]
    elif not cleaned.startswith(default_code):
        # If it starts directly with mobile prefix '8' (e.g. 8123456789)
        if default_code == '62' and cleaned.startswith('8'):
            cleaned = '62' + cleaned

    return cleaned


def validate_phone_number(phone, country_code='62'):
    """
    Validate phone number format.
    Checks whether the phone number is valid for WhatsApp messaging.

    For Indonesia ('62'):
        - Must start with '628'
        - Followed by 7 to 11 digits (total length: 10 to 14 digits)

    For General International:
        - E.164 compliance: 9 to 15 digits total, starting with a non-zero digit.

    :param phone: Raw or normalized phone number
    :param country_code: Country code to validate against (default '62')
    :return: Tuple (is_valid: bool, reason: str or None)
    """
    if not phone:
        return False, "Nomor telepon tidak boleh kosong"

    normalized = normalize_phone_number(phone, default_country_code=country_code)
    if not normalized:
        return False, "Nomor telepon tidak valid atau kosong"

    c_code = sanitize_country_code(country_code)

    if c_code == '62':
        # Indonesian mobile regex: starts with 628, followed by valid provider digit [1-9], then 6-10 digits
        # Total digits between 10 and 14 digits (e.g. 628123456789 = 12 digits)
        if not normalized.startswith('628'):
            return False, "Nomor WhatsApp Indonesia harus berupa nomor ponsel (diawali dengan 08 / 628)"
        if not re.match(r'^628[1-9][0-9]{6,10}$', normalized):
            return False, "Format nomor ponsel Indonesia tidak valid (panjang digit harus 10-14 digit)"
    else:
        # General E.164 validation: 9 to 15 digits
        if not re.match(r'^[1-9][0-9]{8,14}$', normalized):
            return False, "Format nomor telepon internasional tidak valid (harus 9-15 digit)"

    return True, None


def is_valid_whatsapp_number(phone, country_code='62'):
    """
    Convenience boolean helper to check if a phone number is valid for WhatsApp.
    :return: bool
    """
    is_valid, _ = validate_phone_number(phone, country_code=country_code)
    return is_valid
