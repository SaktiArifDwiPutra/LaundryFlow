# -*- coding: utf-8 -*-
import re


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
        cleaned = default_country_code + cleaned[1:]
    elif not cleaned.startswith(default_country_code):
        # If it starts directly with mobile prefix '8' (e.g. 8123456789)
        if default_country_code == '62' and cleaned.startswith('8'):
            cleaned = '62' + cleaned

    return cleaned
