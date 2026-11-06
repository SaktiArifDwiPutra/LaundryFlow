import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/customer.dart';
import '../models/order_option.dart';
import '../models/service.dart';
import '../models/service_speed.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
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
            isDense: true,
            border: OutlineInputBorder(),
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
            isDense: true,
            border: const OutlineInputBorder(),
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
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('×'),
                ),
                Expanded(
                  child: TextField(
                    controller: line.width,
                    keyboardType: decimal,
                    decoration: const InputDecoration(
                      labelText: 'Lebar (m)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Luas: ${formatQty(double.parse(area.toStringAsFixed(2)))} m²',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
    }
  }

  Widget _lineCard(_LineDraft line, List<Service> services) {
    return Card(
      key: ObjectKey(line),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<Service>(
                    isExpanded: true,
                    value: line.service,
                    hint: const Text('Pilih layanan'),
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
                IconButton(
                  onPressed: _lines.length > 1 ? () => _removeLine(line) : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (line.service != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: _amountFields(line),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 12),
                child: TextField(
                  controller: line.details,
                  decoration: const InputDecoration(
                    labelText: 'Catatan barang (opsional)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Baru')),
      body: FutureBuilder<_FormData>(
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

          final String sameDaySubtitle;
          if (sameDay == null) {
            sameDaySubtitle = 'Tidak tersedia';
          } else if (!sameDay.available) {
            sameDaySubtitle = 'Sedang tidak tersedia';
          } else if (sameDay.fee > 0) {
            sameDaySubtitle =
                'Selesai di hari yang sama • +${formatRupiah(sameDay.fee)}';
          } else {
            sameDaySubtitle =
                'Selesai di hari yang sama • biaya tambahan dihitung sistem';
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Pelanggan', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(_customer?.name ?? 'Pilih pelanggan'),
                  subtitle: _customer == null ? null : Text(_customer!.phone),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickCustomer,
                ),
              ),
              const SizedBox(height: 24),
              Text('Layanan', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final line in _lines) _lineCard(line, data.services),
              TextButton.icon(
                onPressed: () => setState(() => _lines.add(_LineDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Tambah layanan'),
              ),
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Same Day Service'),
                subtitle: Text(sameDaySubtitle),
                secondary: const Icon(Icons.bolt, color: Colors.orange),
                value: sameDayOn,
                onChanged: sameDayAvailable
                    ? (on) => setState(
                          () => _priority = on
                              ? OrderPriority.express
                              : OrderPriority.regular,
                        )
                    : null,
              ),
              const SizedBox(height: 16),
              if (useMock) ...[
                Text('Pengambilan', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                FulfillmentFields(
                  value: _fulfillment,
                  onChanged: (f) => setState(() => _fulfillment = f),
                  address: _address,
                  fee: _fee,
                  onFieldChanged: () => setState(() {}),
                ),
              ] else
                Text(
                  'Pilihan ambil sendiri / diantar belum tersedia di server.',
                  style: textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Catatan pesanan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const Divider(height: 32),
              _AmountRow(
                label: 'Layanan (perkiraan)',
                value: formatRupiah(servicesTotal),
              ),
              if (speedFee > 0)
                _AmountRow(
                  label: 'Same Day',
                  value: formatRupiah(speedFee),
                ),
              if (deliveryFee > 0)
                _AmountRow(label: 'Ongkir', value: formatRupiah(deliveryFee)),
              _AmountRow(
                label: 'Total (perkiraan)',
                value: formatRupiah(servicesTotal + speedFee + deliveryFee),
                bold: true,
              ),
              const SizedBox(height: 4),
              Text(
                'Total resmi dihitung sistem saat pesanan disimpan.',
                style: textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Menyimpan...' : 'Simpan Pesanan'),
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}