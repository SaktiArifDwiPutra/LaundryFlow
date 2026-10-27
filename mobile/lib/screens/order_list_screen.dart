import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../repositories/repositories.dart';
import '../utils/format.dart';
import '../widgets/status_chip.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _search = TextEditingController();
  OrderStatus? _status; // null = semua status
  String _query = '';
  late Future<List<Order>> _future;

  /// Status yang bisa dipilih sebagai filter (tanpa "unknown").
  static final _filters =
      OrderStatus.values.where((s) => s != OrderStatus.unknown).toList();

  bool get _hasFilter => _status != null || _query.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Order>> _fetch() =>
      orderRepository.list(status: _status, q: _query);

  void _reload() {
    setState(() {
      _future = _fetch();
    });
  }

  void _setStatus(OrderStatus? status) {
    _status = status;
    _reload();
  }

  void _submitSearch(String text) {
    _query = text.trim();
    _reload();
  }

  void _clearSearch() {
    _search.clear();
    _query = '';
    _reload();
  }

  Future<void> _openDetail(Order order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
    );
    if (!mounted) return;
    _reload();
  }

  Future<void> _newOrder() async {
    final created = await Navigator.of(context).push<Order>(
      MaterialPageRoute(builder: (_) => const NewOrderScreen()),
    );
    if (created == null || !mounted) return;
    // Reset filter supaya pesanan baru pasti kelihatan.
    _status = null;
    _search.clear();
    _query = '';
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pesanan ${created.number} dibuat')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        icon: const Icon(Icons.add),
        label: const Text('Pesanan Baru'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: _submitSearch,
              decoration: InputDecoration(
                hintText: 'Cari nama, nomor HP, atau nomor pesanan',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text('Semua'),
                    selected: _status == null,
                    onSelected: (_) => _setStatus(null),
                  ),
                ),
                for (final s in _filters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(s.label),
                      selected: _status == s,
                      onSelected: (_) => _setStatus(s),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Order>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Gagal memuat pesanan: ${snapshot.error}'),
                  );
                }

                final orders = snapshot.data!;
                if (orders.isEmpty) {
                  return Center(
                    child: Text(
                      _hasFilter
                          ? 'Tidak ada pesanan yang cocok.'
                          : 'Belum ada pesanan.',
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 88),
                    itemCount: orders.length,
                    itemBuilder: (context, index) => _OrderCard(
                      order: orders[index],
                      onTap: () => _openDetail(orders[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final service = order.lines.isEmpty ? '-' : order.lines.first.serviceName;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customer.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.number} • $service',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupiah(order.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  StatusChip(status: order.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}