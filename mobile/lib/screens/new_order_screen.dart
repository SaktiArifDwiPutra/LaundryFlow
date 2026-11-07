import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
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

  /// Ongkir hanya berlaku di mode mock (server belum punya field pengantaran).
  int get _deliveryFee => useMock && _fulfillment == Fulfillment.delivery
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
          content: Text('⚠️ Pilih pelanggan sebelum menyimpan pesanan.'),
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

    final delivery = useMock && _fulfillment == Fulfillment.delivery;
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
        fulfillment: useMock ? _fulfillment : Fulfillment.pickup,
        deliveryAddress: delivery ? _address.text : '',
        deliveryFee: _deliveryFee,
      );
      if (!mounted) return;
      Navigator.of(context).pop(order);
    } on OrderValidationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal menyimpan pesanan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildCustomerCard(bool isDark) {
    if (_customer == null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _error != null && _customer == null
                ? AppColors.danger
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: _error != null && _customer == null ? 1.8 : 1.0,
          ),
          boxShadow: AppColors.cardShadow(isDark: isDark),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _pickCustomer,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih / Cari Pelanggan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ketik nama atau no HP untuk memilih pelanggan',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final c = _customer!;
    final initial = c.name.isNotEmpty ? c.name[0].toUpperCase() : 'P';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.5,
        ),
        boxShadow: AppColors.cardShadow(isDark: isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
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
                      Text(
                        c.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle, size: 15, color: AppColors.success),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.phone.isEmpty ? 'Tanpa nomor HP' : c.phone,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.neutral,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: _pickCustomer,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(60, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ganti', style: TextStyle(fontSize: 12)),
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
                  icon: const Icon(Icons.remove),
                  tooltip: 'Kurang 0.5 kg',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.amount,
                    keyboardType: decimal,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Berat Timbangan (kg)',
                      hintText: '0.0',
                      suffixText: 'kg',
                      suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // Quick Increment Button
                IconButton.filledTonal(
                  onPressed: () => _quickAddWeight(line, 0.5),
                  icon: const Icon(Icons.add),
                  tooltip: 'Tambah 0.5 kg',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Quick preset pills (Gaptek friendly)
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('+1 kg'),
                  onPressed: () => _quickAddWeight(line, 1.0),
                ),
                ActionChip(
                  label: const Text('+2 kg'),
                  onPressed: () => _quickAddWeight(line, 2.0),
                ),
                ActionChip(
                  label: const Text('+5 kg'),
                  onPressed: () => _quickAddWeight(line, 5.0),
                ),
                ActionChip(
                  label: const Text('Reset'),
                  avatar: const Icon(Icons.refresh, size: 14),
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
                // Quick Decrement Button
                IconButton.filledTonal(
                  onPressed: () => _quickAddUnit(line, -1),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Kurang 1',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Jumlah (${service.unit})',
                      hintText: '1',
                      suffixText: service.unit,
                      suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // Quick Increment Button
                IconButton.filledTonal(
                  onPressed: () => _quickAddUnit(line, 1),
                  icon: const Icon(Icons.add),
                  tooltip: 'Tambah 1',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('+1'),
                  onPressed: () => _quickAddUnit(line, 1),
                ),
                ActionChip(
                  label: const Text('+2'),
                  onPressed: () => _quickAddUnit(line, 2),
                ),
                ActionChip(
                  label: const Text('+5'),
                  onPressed: () => _quickAddUnit(line, 5),
                ),
              ],
            ),
          ],
        );

      case PricingType.area:
        final area = (_num(line.length.text) ?? 0) * (_num(line.width.text) ?? 0);
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
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('×', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryContainerLight.withValues(alpha: isDark ? 0.2 : 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Total Luas: ${formatQty(double.parse(area.toStringAsFixed(2)))} m²',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildLineCard(_LineDraft line, List<Service> services, int index, bool isDark) {
    final qty = _billable(line);
    final subtotal = (line.service != null && qty > 0)
        ? (qty * line.service!.unitPrice).round()
        : 0;

    return Container(
      key: ObjectKey(line),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: AppColors.cardShadow(isDark: isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Layanan #${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (_lines.length > 1)
                  IconButton(
                    onPressed: () => _removeLine(line),
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                    tooltip: 'Hapus Layanan Ini',
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Dropdown Layanan
            DropdownButtonFormField<Service>(
              initialValue: line.service,
              decoration: const InputDecoration(
                labelText: 'Pilih Jenis Layanan',
                prefixIcon: Icon(Icons.local_laundry_service_outlined),
              ),
              isExpanded: true,
              items: [
                for (final s in services)
                  DropdownMenuItem(
                    value: s,
                    child: Text(
                      '${s.name} (${formatRupiah(s.unitPrice)}/${s.unit})',
                      overflow: TextOverflow.ellipsis,
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
                  hintText: 'Misal: 2 kemeja, 1 jeans biru',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              if (subtotal > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal Layanan',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        formatRupiah(subtotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.primary,
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
    );
  }

  Widget _buildSpeedSelector(List<ServiceSpeed> speeds, bool isDark) {
    final sameDay = speeds.where((s) => s.isSameDay);
    final sameDaySpeed = sameDay.isNotEmpty ? sameDay.first : null;
    final sameDayAvailable = sameDaySpeed?.available == true;
    final sameDayFee = sameDaySpeed?.fee ?? 0;

    return Row(
      children: [
        // Reguler Card
        Expanded(
          child: _SpeedOptionCard(
            title: 'Reguler',
            subtitle: 'Standar antrean (2-3 hari)',
            feeText: 'Rp 0',
            icon: Icons.access_time,
            isSelected: _priority == OrderPriority.regular,
            activeColor: AppColors.primary,
            isDark: isDark,
            onTap: () => setState(() => _priority = OrderPriority.regular),
          ),
        ),
        const SizedBox(width: 10),
        // Same Day Card
        Expanded(
          child: _SpeedOptionCard(
            title: 'Same Day',
            subtitle: sameDayAvailable ? 'Selesai hari yang sama' : 'Sedang tidak tersedia',
            feeText: sameDayFee > 0 ? '+${formatRupiah(sameDayFee)}' : 'Prioritas',
            icon: Icons.bolt,
            isSelected: _priority == OrderPriority.express,
            activeColor: AppColors.warning,
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
        title: const Text('Buat Pesanan Baru'),
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
                    const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text('Gagal memuat layanan: ${snapshot.error}', textAlign: TextAlign.center),
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
          final speedFee = (_priority == OrderPriority.express && sameDaySpeed.isNotEmpty)
              ? sameDaySpeed.first.fee
              : 0;

          final totalBill = _servicesTotal + speedFee + _deliveryFee;

          return Column(
            children: [
              // Scrollable Form Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Step 1: Customer Card
                    const Text(
                      '1. Data Pelanggan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    _buildCustomerCard(isDark),
                    const SizedBox(height: 20),

                    // Step 2: Laundry Services
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '2. Layanan & Berat/Jumlah',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _lines.add(_LineDraft())),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tambah Layanan', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (int i = 0; i < _lines.length; i++)
                      _buildLineCard(_lines[i], services, i, isDark),
                    const SizedBox(height: 16),

                    // Step 3: Speed
                    const Text(
                      '3. Kecepatan Pengerjaan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    _buildSpeedSelector(speeds, isDark),
                    const SizedBox(height: 20),

                    // Step 4: Notes & Extra
                    const Text(
                      '4. Catatan Tambahan (Opsional)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Misal: Pisahkan pakaian luntur, jangan pakai pewangi',
                      ),
                    ),

                    if (useMock) ...[
                      const SizedBox(height: 20),
                      FulfillmentFields(
                        value: _fulfillment,
                        address: _address,
                        fee: _fee,
                        onChanged: (f) => setState(() => _fulfillment = f),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.dangerText.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.dangerText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
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

              // Pinned Bottom Action Bar (Gaptek Cashier Friendly)
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? const Color(0x33000000) : const Color(0x0C000000),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Total Summary
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Estimasi Total Tagihan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.neutral,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatRupiah(totalBill),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.primary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Primary Action Button
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                                Icon(Icons.check_circle_outline, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Simpan Pesanan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
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
              ? activeColor.withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: AppColors.cardShadow(isDark: isDark),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: isSelected ? activeColor : AppColors.neutral,
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, size: 18, color: activeColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.neutral,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      feeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
