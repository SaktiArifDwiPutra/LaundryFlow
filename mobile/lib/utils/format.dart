String formatRupiah(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp $buf';
}

String formatQty(double qty) =>
    qty % 1 == 0 ? qty.toInt().toString() : qty.toString();

String _two(int n) => n.toString().padLeft(2, '0');

String formatDue(DateTime due, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final days = dueDay.difference(today).inDays;
  final time = '${_two(due.hour)}:${_two(due.minute)}';

  if (days == 0) return 'Hari ini $time';
  if (days == 1) return 'Besok $time';
  if (days == -1) return 'Kemarin $time';
  if (days > 1 && days < 7) {
    const names = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return '${names[due.weekday - 1]} $time';
  }
  return '${_two(due.day)}/${_two(due.month)} $time';
}

String formatOverdue(DateTime due, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(due);
  if (diff.inHours < 1) {
    final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return '$minutes menit';
  }
  if (diff.inHours < 48) return '${diff.inHours} jam';
  return '${diff.inDays} hari';
}

int parseRupiah(String text) =>
    int.tryParse(text.replaceAll(RegExp(r'\D'), '')) ?? 0;

bool isWholeUnit(String unit) {
  const whole = {'pcs', 'pc', 'potong', 'buah', 'unit', 'units', 'set', 'lembar'};
  return whole.contains(unit.trim().toLowerCase());
}