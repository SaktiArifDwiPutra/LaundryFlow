import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer.dart';
import '../models/order_option.dart';
import '../models/service.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../utils/format.dart';
import '../widgets/fulfillment_fields.dart';
import 'customer_list_screen.dart';

class _LineDraft {
  Service? service;
  final TextEditingController qty = TextEditingController();
}

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  late final Future<List<Service>> _servicesFuture;
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
    _servicesFuture = serviceRepository.list();
  }

  @override
  void dispose() {
    _notes.dispose();
    _address.dispose();
    _fee.dispose();
    for (final line in _lines) {
      line.qty.dispose();
    }
    super.dispose();
  }

  double? _parseQty(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  int get _servicesTotal {
    var sum = 0;
    for (final line in _lines) {
      final service = line.service;
      final qty = _parseQty(line.qty.text);
      if (service != null && qty != null && qty > 0) {
        sum += (qty * service.unitPrice).round();
      }
    }
    return sum;
  }

  int get _deliveryFee =>
      _fulfillment == Fulfillment.delivery ? parseRupiah(_fee.text) : 0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => line.qty.dispose());
  }

  Future<void> _save() async {
    final customer = _customer;
    if (customer == null) {
      setState(() => _error = 'Pilih pelanggan dulu.');
      return;
    }

    final inputs = <OrderLineInput>[];
    for (final line in _lines) {
      final service = line.service;
      final qty = _parseQty(line.qty.text);
      if (service == null || qty == null || qty <= 0) {
        setState(() => _error = 'Lengkapi layanan dan jumlah di semua baris.');
        return;
      }
      if (isWholeUnit(service.unit) && qty % 1 != 0) {
        setState(
          () => _error = 'Jumlah "${service.name}" harus bilangan bulat.',
        );
        return;
      }
      inputs.add(OrderLineInput(service: service, qty: qty));
    }

    if (_fulfillment == Fulfillment.delivery && _address.text.trim().isEmpty) {
      setState(() => _error = 'Alamat pengantaran wajib diisi.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final order = await orderRepository.create(
        customer: customer,
        lines: inputs,
        notes: _notes.text.trim(),
        priority: _priority,
        fulfillment: _fulfillment,
        deliveryAddress: _address.text,
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Baru')),
      body: FutureBuilder<List<Service>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat layanan: ${snapshot.error}'),
            );
          }
          final services = snapshot.data!;

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
              for (final line in _lines)
                Card(
                  key: ObjectKey(line),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(
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
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: line.qty,
                            keyboardType: (line.service != null &&
                                    isWholeUnit(line.service!.unit))
                                ? TextInputType.number
                                : const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            inputFormatters: (line.service != null &&
                                    isWholeUnit(line.service!.unit))
                                ? [FilteringTextInputFormatter.digitsOnly]
                                : null,
                            decoration: InputDecoration(
                              labelText: line.service?.unit ?? 'Jumlah',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _lines.length > 1 ? () => _removeLine(line) : null,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _lines.add(_LineDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Tambah layanan'),
              ),
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Express'),
                subtitle: const Text('Lebih cepat, biaya lebih tinggi'),
                secondary: const Icon(Icons.bolt, color: Colors.orange),
                value: _priority == OrderPriority.express,
                onChanged: (on) => setState(
                  () => _priority =
                      on ? OrderPriority.express : OrderPriority.regular,
                ),
              ),
              const SizedBox(height: 16),
              Text('Pengambilan', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              FulfillmentFields(
                value: _fulfillment,
                onChanged: (f) => setState(() => _fulfillment = f),
                address: _address,
                fee: _fee,
                onFieldChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const Divider(height: 32),
              _AmountRow(
                label: 'Layanan (perkiraan)',
                value: formatRupiah(_servicesTotal),
              ),
              if (_deliveryFee > 0)
                _AmountRow(label: 'Ongkir', value: formatRupiah(_deliveryFee)),
              _AmountRow(
                label: 'Total (perkiraan)',
                value: formatRupiah(_servicesTotal + _deliveryFee),
                bold: true,
              ),
              const SizedBox(height: 4),
              Text(
                'Biaya Express (bila dipilih) dihitung sistem saat pesanan disimpan.',
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
  const _AmountRow({required this.label, required this.value, this.bold = false});

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