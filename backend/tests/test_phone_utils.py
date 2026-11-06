# -*- coding: utf-8 -*-
import unittest
from ..utils.phone_utils import (
    normalize_phone_number,
    validate_phone_number,
    is_valid_whatsapp_number,
    sanitize_country_code,
)


class TestPhoneUtils(unittest.TestCase):
    """
    Unit test suite untuk utility normalisasi dan validasi nomor telepon WhatsApp.
    Menguji berbagai edge cases format nomor telepon lokal dan internasional.
    """

    def test_01_normalization_standard_indonesian(self):
        """Uji normalisasi nomor ponsel standar Indonesia (awalan 08)."""
        self.assertEqual(normalize_phone_number('08978890178'), '628978890178')
        self.assertEqual(normalize_phone_number('081234567890'), '6281234567890')

    def test_02_normalization_with_separators(self):
        """Uji normalisasi nomor dengan berbagai pemisah: spasi, strip, titik, kurung."""
        self.assertEqual(normalize_phone_number('0897-8890-178'), '628978890178')
        self.assertEqual(normalize_phone_number('(0897) 8890 178'), '628978890178')
        self.assertEqual(normalize_phone_number('0897.8890.178'), '628978890178')
        self.assertEqual(normalize_phone_number(' +62 (897) - 8890 - 178 '), '628978890178')

    def test_03_normalization_international_prefixes(self):
        """Uji normalisasi awalan internasional (+, 00, atau tanpa awalan)."""
        self.assertEqual(normalize_phone_number('+628978890178'), '628978890178')
        self.assertEqual(normalize_phone_number('00628978890178'), '628978890178')
        self.assertEqual(normalize_phone_number('628978890178'), '628978890178')

    def test_04_normalization_direct_prefix_8(self):
        """Uji normalisasi nomor yang langsung diawali angka 8 tanpa 0."""
        self.assertEqual(normalize_phone_number('8978890178'), '628978890178')
        self.assertEqual(normalize_phone_number('81234567890'), '6281234567890')

    def test_05_normalization_empty_and_invalid_inputs(self):
        """Uji penanganan input kosong, None, atau karakter non-numerik."""
        self.assertEqual(normalize_phone_number(''), '')
        self.assertEqual(normalize_phone_number(None), '')
        self.assertEqual(normalize_phone_number(False), '')
        self.assertEqual(normalize_phone_number('   '), '')
        self.assertEqual(normalize_phone_number('abc-xyz'), '')

    def test_06_sanitize_country_code(self):
        """Uji sanitasi input country code."""
        self.assertEqual(sanitize_country_code('62'), '62')
        self.assertEqual(sanitize_country_code('+62'), '62')
        self.assertEqual(sanitize_country_code('0062'), '62')
        self.assertEqual(sanitize_country_code(''), '62')
        self.assertEqual(sanitize_country_code(None), '62')

    def test_07_validation_valid_indonesian_mobiles(self):
        """Uji validasi nomor ponsel Indonesia yang sah."""
        valid_numbers = [
            '08978890178',
            '+6281234567890',
            '6281339529934',
            '81987654321',
            '0852-1234-5678',
        ]
        for num in valid_numbers:
            is_valid, err = validate_phone_number(num)
            self.assertTrue(is_valid, f"Seharusnya valid untuk: {num}, error: {err}")
            self.assertIsNone(err)
            self.assertTrue(is_valid_whatsapp_number(num))

    def test_08_validation_invalid_indonesian_mobiles(self):
        """Uji penolakan nomor telepon Indonesia yang tidak valid untuk WhatsApp."""
        # Telepon rumah / PSTN
        is_valid, err = validate_phone_number('0215551234')
        self.assertFalse(is_valid)
        self.assertIn("harus berupa nomor ponsel", err)
        self.assertFalse(is_valid_whatsapp_number('0215551234'))

        # Terlalu pendek
        is_valid, err = validate_phone_number('08123')
        self.assertFalse(is_valid)
        self.assertIn("tidak valid", err)

        # Terlalu panjang
        is_valid, err = validate_phone_number('081234567890123456')
        self.assertFalse(is_valid)
        self.assertIn("tidak valid", err)

        # Input kosong
        is_valid, err = validate_phone_number('')
        self.assertFalse(is_valid)
        self.assertIn("tidak boleh kosong", err)
