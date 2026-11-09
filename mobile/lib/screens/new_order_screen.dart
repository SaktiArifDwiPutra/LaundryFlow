import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_exception.dart';
import '../models/customer.dart';
import '../models/order_option.dart';
import '../models/service.dart';
import '../models/service_speed.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/fulfillment_fields.dart';
import 'customer_list_screen.dart';

/// Satu baris isian layanan laundry.
class _LineDraft {
  Service? service;
  final TextEditingController amount = TextEditingController(); // kg / jumlah
  final TextEditingController length = TextEditingController();
  final TextEditingController width = TextEditingController();
  final TextEditingController details = TextEditingController();

  void dispose() {
    amount.dispose();
    length.dispose();
    width.dispose();
    details.dispose();
  }
}

class _FormData {
  const _FormData(this.services, this.speeds);

  final List<Service> services;
  final List<ServiceSpeed> speeds;
}

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key, this.initialCustomer});

  /// Pre-fills customer if opened from customer list
  final Customer? initialCustomer;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  late final Future<_FormData> _dataFuture;
  final List<_LineDraft> _lines = [_LineDraft()];
  final _notes = TextEditingController();
  final _address = TextEditingController();
  final _fee = TextEditingController();
  Customer? _customer;
  OrderPriority _priority = OrderPriority.regular;
  Fulfillment _fulfillment = Fulfillment.pickup;
  PricingType? _categoryFilter; // null = Semua
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
    if (widget.initialCustomer != null) {
      _customer = widget.initialCustomer;
      if (widget.initialCustomer!.address.isNotEmpty) {
        _address.text = widget.initialCustomer!.address;
      }
    }
  }

  Future<_FormData> _load() async {
    final results = await Future.wait<Object>([
      serviceRepository.list(),
      serviceRepository.speeds(),
    ]);
    return _FormData(
      results[0] as List<Service>,
      results[1] as List<ServiceSpeed>,
    );
  }

  @override
  void dispose() {
    _notes.dispose();
    _address.dispose();
    _fee.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  /// Menerima "3,5" maupun "3.5".
  double? _num(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  /// Angka yang dikalikan harga satuan, sesuai jenis layanan.
  double _billable(_LineDraft d) {
    final s = d.service;
    if (s == null) return 0;
    return switch (s.pricingType) {
      PricingType.weight || PricingType.unit => _num(d.amount.text) ?? 0,
      PricingType.area =>
        (_num(d.length.text) ?? 0) * (_num(d.width.text) ?? 0),
    };
  }

  /// Perkiraan total layanan; angka resmi dari server.
  int get _servicesTotal {
    var sum = 0;
    for (final line in _lines) {
      final service = line.service;
      final qty = _billable(line);
      if (service != null && qty > 0) {
        sum += (qty * service.unitPrice).round();
      }
    }
    return sum;
  }

  int get _deliveryFee => _fulfillment == Fulfillment.delivery
      ? parseRupiah(_fee.text)
      : 0;

  Future<void> _pickCustomer() async {
    final picked = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => const CustomerListScreen(selectMode: true),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customer = picked;
      if (_address.text.isEmpty && picked.address.isNotEmpty) {
        _address.text = picked.address;
      }
      _error = null;
    });
  }

  void _removeLine(_LineDraft line) {
    setState(() => _lines.remove(line));
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  void _quickAddWeight(_LineDraft line, double delta) {
    final current = _num(line.amount.text) ?? 0.0;
    final next = (current + delta).clamp(0.0, 999.0);
    setState(() {
      line.amount.text = next == next.roundToDouble()
          ? next.toStringAsFixed(0)
          : next.toStringAsFixed(1);
    });
  }

  void _quickAddUnit(_LineDraft line, int delta) {
    final current = int.tryParse(line.amount.text) ?? 0;
    final next = (current + delta).clamp(0, 999);
    setState(() {
      line.amount.text = next.toString();
    });
  }

  Color _serviceTypeAccent(PricingType? type) {
    return switch (type) {
      PricingType.weight => AppColors.primaryBright,
      PricingType.unit => AppColors.teal,
      PricingType.area => AppColors.violet,
      null => AppColors.indigo,
    };
  }

  IconData _serviceTypeIcon(PricingType? type) {
    return switch (type) {
      PricingType.weight => Icons.scale_rounded,
      PricingType.unit => Icons.checkroom_rounded,
      PricingType.area => Icons.square_foot_rounded,
      null => Icons.local_laundry_service_rounded,
    };
  }

  String _serviceTypeBadge(PricingType? type) {
    return switch (type) {
      PricingType.weight => 'KILOAN (KG)',
      PricingType.unit => 'SATUAN (PCS)',
      PricingType.area => 'KARPET (M²)',
      null => 'PILIH LAYANAN',
    };
  }

  /// Menyusun isian satu baris sesuai jenis layanan, atau pesan kesalahan.
  ({OrderLineInput? input, String? error}) _buildInput(_LineDraft line) {
    final service = line.service;
    if (service == null) {
      return (input: null, error: 'Pilih jenis layanan di setiap baris.');
    }
    final details = line.details.text.trim();

    switch (service.pricingType) {
      case PricingType.weight:
        final w = _num(line.amount.text);
        if (w == null || w <= 0) {
          return (
            input: null,
            error: 'Masukkan berat (kg) untuk "${service.name}".',
          );
        }
        return (
          input: OrderLineInput(
            service: service,
            weight: w,
            itemDetails: details,
          ),
          error: null,
        );
      case PricingType.unit:
        final q = _num(line.amount.text);
        if (q == null || q <= 0 || q != q.roundToDouble()) {
          return (
            input: null,
            error:
                'Jumlah "${service.name}" harus bilangan bulat lebih dari 0.',
          );
        }
        return (
          input: OrderLineInput(
            service: service,
            quantity: q,
            itemDetails: details,
          ),
          error: null,
        );
      case PricingType.area:
        final l = _num(line.length.text);
        final w = _num(line.width.text);
        if (l == null || w == null || l <= 0 || w <= 0) {
          return (
            input: null,
            error: 'Isi panjang dan lebar (m) untuk "${service.name}".',
          );
        }
        return (
          input: OrderLineInput(
            service: service,
            length: l,
            width: w,
            itemDetails: details,
          ),
          error: null,
        );
    }
  }

  Future<void> _save() async {
    final customer = _customer;
    if (customer == null) {
      setState(() => _error = 'Pilih pelanggan terlebih dahulu.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih pelanggan sebelum menyimpan pesanan.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final inputs = <OrderLineInput>[];
    for (final line in _lines) {
      final r = _buildInput(line);
      if (r.error != null) {
        setState(() => _error = r.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(r.error!),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      inputs.add(r.input!);
    }

    final delivery = _fulfillment == Fulfillment.delivery;
    if (delivery && _address.text.trim().isEmpty) {
      setState(() => _error = 'Alamat pengantaran wajib diisi.');
      return;
    }

    // Same Day hanya dikirim kalau server menyatakan tersedia.
    final data = await _dataFuture;
    final sameDay = data.speeds.where((s) => s.isSameDay);
    final sameDayAvailable = sameDay.isNotEmpty && sameDay.first.available;
    final priority =
        (_priority == OrderPriority.express && sameDayAvailable)
            ? OrderPriority.express
            : OrderPriority.regular;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final order = await orderRepository.create(
        customer: customer,
        lines: inputs,
        notes: _notes.text.trim(),
        priority: priority,
        fulfillment: _fulfillment,
        deliveryAddress: delivery ? _address.text.trim() : '',
        deliveryFee: _deliveryFee,
      );
      if (!mounted) return;
      Navigator.of(context).pop(order);
    } on OrderValidationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal menyimpan pesanan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildSectionTitle(
    String number,
    String title,
    Color badgeColor, {
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildCustomerCard(bool isDark) {
    if (_customer == null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _error != null && _customer == null
                ? AppColors.danger
                : AppColors.primaryBright.withValues(alpha: isDark ? 0.5 : 0.35),
            width: 1.6,
          ),
          boxShadow: AppColors.cardShadow(isDark: isDark),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: _pickCustomer,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryActionGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppColors.glowShadow(
                        AppColors.primaryBright,
                        isDark: isDark,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih / Tambah Pelanggan',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ketuk untuk mencari nama atau nomor WhatsApp',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primaryContainerDark
                          : AppColors.primaryContainerLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Pilih',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final c = _customer!;
    final avatar = AppColors.avatarStyle(c.name, isDark: isDark);
    final initial = c.name.isNotEmpty ? c.name[0].toUpperCase() : 'P';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: isDark ? 0.65 : 0.45),
          width: 1.6,
        ),
        boxShadow: AppColors.cardShadow(isDark: isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: avatar.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: avatar.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.name,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppColors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_iphone_rounded,
                        size: 13,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        c.phone.isEmpty ? 'Tanpa nomor HP' : c.phone,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (c.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.neutral,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            c.address,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.neutral,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickCustomer,
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Ganti', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(76, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountFields(_LineDraft line) {
    final service = line.service!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const decimal = TextInputType.numberWithOptions(decimal: true);

    switch (service.pricingType) {
      case PricingType.weight:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Quick Decrement Button
                IconButton.filledTonal(
                  onPressed: () => _quickAddWeight(line, -0.5),
                  icon: const Icon(Icons.remove_rounded),
                  tooltip: 'Kurang 0.5 kg',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.amount,
                    keyboardType: decimal,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Berat Timbangan (kg)',
                      hintText: '0.0',
                      suffixText: 'kg',
                      suffixStyle: TextStyle(fontWeight: FontWeight.w800),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // Quick Increment Button
                IconButton.filledTonal(
                  onPressed: () => _quickAddWeight(line, 0.5),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Tambah 0.5 kg',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('+1 kg'),
                  onPressed: () => _quickAddWeight(line, 1.0),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('+2 kg'),
                  onPressed: () => _quickAddWeight(line, 2.0),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('+5 kg'),
                  onPressed: () => _quickAddWeight(line, 5.0),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('+10 kg'),
                  onPressed: () => _quickAddWeight(line, 10.0),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('Reset'),
                  avatar: const Icon(Icons.refresh_rounded, size: 14),
                  onPressed: () => setState(() => line.amount.clear()),
                ),
              ],
            ),
          ],
        );

      case PricingType.unit:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => _quickAddUnit(line, -1),
                  icon: const Icon(Icons.remove_rounded),
                  tooltip: 'Kurang 1',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Jumlah (${service.unit})',
                      hintText: '1',
                      suffixText: service.unit,
                      suffixStyle: const TextStyle(fontWeight: FontWeight.w800),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _quickAddUnit(line, 1),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Tambah 1',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('+1 pcs'),
                  onPressed: () => _quickAddUnit(line, 1),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('+2 pcs'),
                  onPressed: () => _quickAddUnit(line, 2),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('+5 pcs'),
                  onPressed: () => _quickAddUnit(line, 5),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('Reset'),
                  avatar: const Icon(Icons.refresh_rounded, size: 14),
                  onPressed: () => setState(() => line.amount.clear()),
                ),
              ],
            ),
          ],
        );

      case PricingType.area:
        final area =
            (_num(line.length.text) ?? 0) * (_num(line.width.text) ?? 0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.length,
                    keyboardType: decimal,
                    decoration: const InputDecoration(
                      labelText: 'Panjang (m)',
                      suffixText: 'm',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '×',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.violet,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: line.width,
                    keyboardType: decimal,
                    decoration: const InputDecoration(
                      labelText: 'Lebar (m)',
                      suffixText: 'm',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.violetDark.withValues(alpha: 0.45)
                    : AppColors.violetLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.violet.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.square_foot_rounded,
                    size: 16,
                    color: AppColors.violet,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Luas Total: ${formatQty(double.parse(area.toStringAsFixed(2)))} m²',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.violetGlow : AppColors.violet,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildLineCard(
    _LineDraft line,
    List<Service> allServices,
    int index,
    bool isDark,
  ) {
    final qty = _billable(line);
    final subtotal = (line.service != null && qty > 0)
        ? (qty * line.service!.unitPrice).round()
        : 0;
    final accent = _serviceTypeAccent(line.service?.pricingType);

    // Filter services by selected category chip, while always keeping currently chosen service in list
    final filteredServices = _categoryFilter == null
        ? allServices
        : allServices
            .where(
              (s) =>
                  s.pricingType == _categoryFilter || s.id == line.service?.id,
            )
            .toList();

    return Container(
      key: ObjectKey(line),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: line.service != null
              ? accent.withValues(alpha: isDark ? 0.65 : 0.45)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: line.service != null ? 1.6 : 1.2,
        ),
        boxShadow: AppColors.cardShadow(isDark: isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored Top Accent Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.22 : 0.10),
                border: Border(
                  bottom: BorderSide(
                    color: accent.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _serviceTypeIcon(line.service?.pricingType),
                    size: 16,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ITEM #${index + 1} • ${_serviceTypeBadge(line.service?.pricingType)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : accent,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (line.service != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${formatRupiah(line.service!.unitPrice)}/${line.service!.unit}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                  if (_lines.length > 1) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _removeLine(line),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Dropdown
                  DropdownButtonFormField<Service>(
                    initialValue: line.service,
                    decoration: InputDecoration(
                      labelText: 'Pilih Paket Layanan Laundry',
                      prefixIcon: Icon(
                        Icons.local_laundry_service_rounded,
                        color: accent,
                      ),
                    ),
                    isExpanded: true,
                    items: [
                      for (final s in filteredServices)
                        DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.name} (${formatRupiah(s.unitPrice)}/${s.unit})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                    onChanged: (s) => setState(() => line.service = s),
                  ),

                  if (line.service != null) ...[
                    const SizedBox(height: 14),
                    _buildAmountFields(line),
                    const SizedBox(height: 12),
                    TextField(
                      controller: line.details,
                      decoration: const InputDecoration(
                        labelText: 'Rincian Pakaian / Item (Opsional)',
                        hintText: 'Contoh: 3 kemeja putih, 2 celana jeans',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    if (subtotal > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal (${formatQty(qty)} ${line.service!.unit})',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              formatRupiah(subtotal),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: isDark ? Colors.white : accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedSelector(List<ServiceSpeed> speeds, bool isDark) {
    final sameDay = speeds.where((s) => s.isSameDay);
    final sameDaySpeed = sameDay.isNotEmpty ? sameDay.first : null;
    final sameDayAvailable = sameDaySpeed?.available == true;
    final sameDayFee = sameDaySpeed?.fee ?? 0;

    return Row(
      children: [
        Expanded(
          child: _SpeedOptionCard(
            title: 'Reguler',
            subtitle: 'Antrean standar (2-3 hari)',
            feeText: 'Tarif Normal',
            icon: Icons.schedule_rounded,
            isSelected: _priority == OrderPriority.regular,
            activeColor: AppColors.primaryBright,
            isDark: isDark,
            onTap: () => setState(() => _priority = OrderPriority.regular),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SpeedOptionCard(
            title: 'Kilat / Same Day',
            subtitle: sameDayAvailable
                ? 'Selesai hari yang sama'
                : 'Sedang tidak tersedia',
            feeText: sameDayFee > 0
                ? '+ ${formatRupiah(sameDayFee)}'
                : 'Prioritas Kilat',
            icon: Icons.bolt_rounded,
            isSelected: _priority == OrderPriority.express,
            activeColor: AppColors.warmOrangeBright,
            isDark: isDark,
            disabled: !sameDayAvailable,
            onTap: sameDayAvailable
                ? () => setState(() => _priority = OrderPriority.express)
                : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient(isDark: isDark),
          ),
        ),
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Transaksi Kasir Baru',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                ),
              ),
              child: const Text(
                '#NOTA-BARU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<_FormData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat layanan: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _dataFuture = _load()),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final services = data.services;
          final speeds = data.speeds;

          final sameDaySpeed = speeds.where((s) => s.isSameDay);
          final speedFee =
              (_priority == OrderPriority.express && sameDaySpeed.isNotEmpty)
                  ? sameDaySpeed.first.fee
                  : 0;

          final totalBill = _servicesTotal + speedFee + _deliveryFee;

          return Column(
            children: [
              // Scrollable Cashier Form Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    // Step 1: Customer Selection
                    _buildSectionTitle(
                      '1',
                      'Pelanggan Transaksi',
                      AppColors.primaryBright,
                    ),
                    const SizedBox(height: 8),
                    _buildCustomerCard(isDark),
                    const SizedBox(height: 20),

                    // Step 2: Laundry Services + Category Filter Pills
                    _buildSectionTitle(
                      '2',
                      'Layanan & Timbangan',
                      AppColors.indigo,
                      trailing: FilledButton.tonalIcon(
                        onPressed: () =>
                            setState(() => _lines.add(_LineDraft())),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(120, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: isDark
                              ? AppColors.primaryContainerDark
                              : AppColors.primaryContainerLight,
                          foregroundColor:
                              isDark ? Colors.white : AppColors.primary,
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                        label: const Text(
                          'Tambah Baris',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Category Filter Strip (Semua, Kiloan, Satuan, Karpet)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CategoryChip(
                            label: 'Semua Layanan',
                            icon: Icons.apps_rounded,
                            color: AppColors.indigo,
                            selected: _categoryFilter == null,
                            isDark: isDark,
                            onTap: () =>
                                setState(() => _categoryFilter = null),
                          ),
                          const SizedBox(width: 6),
                          _CategoryChip(
                            label: 'Kiloan (kg)',
                            icon: Icons.scale_rounded,
                            color: AppColors.primaryBright,
                            selected: _categoryFilter == PricingType.weight,
                            isDark: isDark,
                            onTap: () => setState(
                              () => _categoryFilter = PricingType.weight,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _CategoryChip(
                            label: 'Satuan (pcs)',
                            icon: Icons.checkroom_rounded,
                            color: AppColors.teal,
                            selected: _categoryFilter == PricingType.unit,
                            isDark: isDark,
                            onTap: () => setState(
                              () => _categoryFilter = PricingType.unit,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _CategoryChip(
                            label: 'Karpet (m²)',
                            icon: Icons.square_foot_rounded,
                            color: AppColors.violet,
                            selected: _categoryFilter == PricingType.area,
                            isDark: isDark,
                            onTap: () => setState(
                              () => _categoryFilter = PricingType.area,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    for (int i = 0; i < _lines.length; i++)
                      _buildLineCard(_lines[i], services, i, isDark),
                    const SizedBox(height: 8),

                    // Step 3: Speed Selector
                    _buildSectionTitle(
                      '3',
                      'Kecepatan Pengerjaan',
                      AppColors.warmOrangeBright,
                    ),
                    const SizedBox(height: 8),
                    _buildSpeedSelector(speeds, isDark),
                    const SizedBox(height: 20),

                    // Step 4: Fulfillment (Pickup / Delivery)
                    _buildSectionTitle(
                      '4',
                      'Metode Serah Terima / Pengantaran',
                      AppColors.cyan,
                    ),
                    const SizedBox(height: 8),
                    FulfillmentFields(
                      value: _fulfillment,
                      address: _address,
                      fee: _fee,
                      onChanged: (f) => setState(() => _fulfillment = f),
                      onFieldChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 20),

                    // Step 5: Notes
                    _buildSectionTitle(
                      '5',
                      'Catatan Kasir / Instruksi Khusus',
                      AppColors.violet,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText:
                            'Contoh: Pisahkan pakaian putih, jangan pakai pelembut...',
                        prefixIcon: Icon(Icons.sticky_note_2_outlined),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.dangerText.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 20,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.dangerText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Sticky Bottom Checkout Dock (Stitch Cashier POS Design)
              Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottomInset),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1.2,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0x55000000)
                          : const Color(0x141E40AF),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Formula Breakdown Strip
                    if (speedFee > 0 || _deliveryFee > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text(
                              'Layanan: ${formatRupiah(_servicesTotal)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (speedFee > 0)
                              Text(
                                '+ Kilat: ${formatRupiah(speedFee)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warmOrange,
                                ),
                              ),
                            if (_deliveryFee > 0)
                              Text(
                                '+ Ongkir: ${formatRupiah(_deliveryFee)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cyan,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        // Total Summary
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'TOTAL TAGIHAN NOTA',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neutral,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatRupiah(totalBill),
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primaryDark,
                                  letterSpacing: -0.5,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Primary Checkout Button with Gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryActionGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppColors.glowShadow(
                              AppColors.primaryBright,
                              isDark: isDark,
                            ),
                          ),
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(176, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Simpan & Buat Nota',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedOptionCard extends StatelessWidget {
  const _SpeedOptionCard({
    required this.title,
    required this.subtitle,
    required this.feeText,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.isDark,
    this.disabled = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String feeText;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final bool isDark;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? activeColor
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.22 : 0.09)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: AppColors.cardShadow(isDark: isDark),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? activeColor
                              : activeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          size: 19,
                          color: isSelected ? Colors.white : activeColor,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: activeColor,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(
                        alpha: isDark ? 0.28 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      feeText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? activeColor : AppColors.neutral,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
