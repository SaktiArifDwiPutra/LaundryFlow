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

/// Satu baris isian yang sedang diketik.
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
  const NewOrderScreen({super.key});

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

  /// Menyusun isian satu baris sesuai jenis layanan, atau pesan kesalahan.
  ({OrderLineInput? input, String? error}) _buildInput(_LineDraft line) {
    final service = line.service;
    if (service == null) {
      return (input: null, error: 'Pilih layanan di semua baris.');
    }
    final details = line.details.text.trim();

    switch (service.pricingType) {
      case PricingType.weight:
        final w = _num(line.amount.text);
        if (w == null || w <= 0) {
          return (
            input: null,
            error: 'Isi berat (kg) untuk "${service.name}".',
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
        if (q == null || q <= 0 || q % 1 != 0) {
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
      setState(() => _error = 'Pilih pelanggan dulu.');
      return;
    }

    final inputs = <OrderLineInput>[];
    for (final line in _lines) {
      final r = _buildInput(line);
      if (r.error != null) {
        setState(() => _error = r.error);
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

  Widget _amountFields(_LineDraft line) {
    final service = line.service!;
    const decimal = TextInputType.numberWithOptions(decimal: true);

    switch (service.pricingType) {
      case PricingType.weight:
        return TextField(
          controller: line.amount,
          keyboardType: decimal,
          decoration: const InputDecoration(
            labelText: 'Berat (kg)',
            hintText: 'Contoh: 3.5',
            suffixText: 'kg',
          ),
          onChanged: (_) => setState(() {}),
        );
      case PricingType.unit:
        return TextField(
          controller: line.amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Jumlah (${service.unit})',
            hintText: 'Contoh: 2',
            suffixText: service.unit,
          ),
          onChanged: (_) => setState(() {}),
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
                  child: Text('×', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryContainerLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
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

  Widget _lineCard(_LineDraft line, List<Service> services) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qty = _billable(line);
    final subtotal = (line.service != null && qty > 0)
        ? (qty * line.service!.unitPrice).round()
        : 0;

    return Card(
      key: ObjectKey(line),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Service>(
                    value: line.service,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Layanan Laundry',
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
                ),
                if (_lines.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removeLine(line),
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    tooltip: 'Hapus Layanan',
                  ),
                ],
              ],
            ),
            if (line.service != null) ...[
              const SizedBox(height: 12),
              _amountFields(line),
              const SizedBox(height: 12),
              TextField(
                controller: line.details,
                decoration: const InputDecoration(
                  labelText: 'Catatan pakaian / detail item (opsional)',
                  hintText: 'Misal: 2 celana jeans, 3 kemeja putih',
                ),
              ),
              if (subtotal > 0) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Subtotal: ${formatRupiah(subtotal)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Pesanan Baru')),
      body: SafeArea(
        child: FutureBuilder<_FormData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Gagal memuat data: ${snapshot.error}'),
              );
            }
            final data = snapshot.data!;
            if (data.services.isEmpty) {
              return const Center(child: Text('Belum ada layanan di server.'));
            }

            final matches = data.speeds.where((s) => s.isSameDay);
            final ServiceSpeed? sameDay = matches.isEmpty ? null : matches.first;
            final sameDayAvailable = sameDay?.available ?? false;
            final sameDayOn =
                _priority == OrderPriority.express && sameDayAvailable;
            final speedFee = sameDayOn ? (sameDay?.fee ?? 0) : 0;
            final deliveryFee = _deliveryFee;
            final servicesTotal = _servicesTotal;
            final grandTotal = servicesTotal + speedFee + deliveryFee;

            final String sameDaySubtitle;
            if (sameDay == null) {
              sameDaySubtitle = 'Tidak tersedia di sistem';
            } else if (!sameDay.available) {
              sameDaySubtitle = 'Sedang tidak menerima order same day';
            } else if (sameDay.fee > 0) {
              sameDaySubtitle =
                  'Selesai hari yang sama • +${formatRupiah(sameDay.fee)}';
            } else {
              sameDaySubtitle = 'Selesai hari yang sama';
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + bottomInset),
              children: [
                // Section 1: Customer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1. Data Pelanggan', style: textTheme.titleMedium),
                    if (_customer != null)
                      TextButton.icon(
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text('Ganti'),
                        onPressed: _pickCustomer,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _customer != null
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _customer != null ? Icons.person : Icons.person_add_outlined,
                        color: _customer != null ? AppColors.primary : AppColors.neutral,
                      ),
                    ),
                    title: Text(
                      _customer?.name ?? 'Pilih Pelanggan',
                      style: textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      _customer == null
                          ? 'Klik untuk mencari pelanggan terdaftar'
                          : (_customer!.phone.isNotEmpty ? _customer!.phone : 'Tanpa nomor HP'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickCustomer,
                  ),
                ),
                const SizedBox(height: 24),

                // Section 2: Services
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('2. Layanan Laundry', style: textTheme.titleMedium),
                    TextButton.icon(
                      onPressed: () => setState(() => _lines.add(_LineDraft())),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah Baris'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final line in _lines) _lineCard(line, data.services),
                const SizedBox(height: 16),

                // Section 3: Speed & Priority
                Text('3. Kecepatan Pengerjaan', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile(
                    title: const Row(
                      children: [
                        Icon(Icons.bolt, color: AppColors.warning, size: 20),
                        SizedBox(width: 8),
                        Text('Layanan Same Day'),
                      ],
                    ),
                    subtitle: Text(sameDaySubtitle),
                    value: sameDayOn,
                    onChanged: sameDayAvailable
                        ? (on) => setState(
                              () => _priority = on
                                  ? OrderPriority.express
                                  : OrderPriority.regular,
                            )
                        : null,
                  ),
                ),
                const SizedBox(height: 24),

                // Section 4: Fulfillment (if mock)
                if (useMock) ...[
                  Text('4. Pengambilan / Pengantaran', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FulfillmentFields(
                        value: _fulfillment,
                        onChanged: (f) => setState(() => _fulfillment = f),
                        address: _address,
                        fee: _fee,
                        onFieldChanged: () => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Section 5: Order Notes
                Text(useMock ? '5. Catatan Kasir' : '4. Catatan Kasir', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan khusus pesanan (opsional)',
                    hintText: 'Misal: Pisahkan pakaian luntur, ekstra pewangi',
                  ),
                ),
                const SizedBox(height: 24),

                // Section 6: Order Summary Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ringkasan Transaksi', style: textTheme.titleMedium),
                        const Divider(height: 20),
                        _AmountRow(
                          label: 'Subtotal Layanan',
                          value: formatRupiah(servicesTotal),
                        ),
                        if (speedFee > 0)
                          _AmountRow(
                            label: 'Biaya Same Day',
                            value: formatRupiah(speedFee),
                          ),
                        if (deliveryFee > 0)
                          _AmountRow(
                            label: 'Ongkos Kirim',
                            value: formatRupiah(deliveryFee),
                          ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Estimasi Total Tagihan',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              formatRupiah(grandTotal),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.dangerText, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Menyimpan ke Odoo...' : 'Simpan & Terbitkan Pesanan'),
                  ),
                ),
                SizedBox(height: 16 + bottomInset),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
