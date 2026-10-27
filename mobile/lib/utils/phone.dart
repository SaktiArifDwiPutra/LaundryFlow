String? normalizePhone(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) {
    digits = '62${digits.substring(1)}';
  } else if (!digits.startsWith('62')) {
    return null;
  }
  return digits.length >= 10 && digits.length <= 15 ? digits : null;
}