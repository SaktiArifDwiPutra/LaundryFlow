import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../repositories/repositories.dart';
import '../theme/app_colors.dart';
import '../widgets/order_tile.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _search = TextEditingController();
  OrderStatus? _status;
  String _query = '';
  late Future<List<Order>> _future;

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
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Pesanan'),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        icon: const Icon(Icons.add),
        label: const Text('Pesanan Baru'),
      ),
      body: Column(
        children: [
          // Search Input Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: _submitSearch,
              decoration: InputDecoration(
                hintText: 'Cari nama, HP, atau no. pesanan...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clearSearch,
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Horizontal Status Filter Chips
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
          const SizedBox(height: 6),

          // Order Stream / List
          Expanded(
            child: FutureBuilder<List<Order>>(
              future: _future,
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
                          Text(
                            'Gagal memuat pesanan: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                            onPressed: _reload,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final orders = snapshot.data!;
                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _hasFilter
                              ? 'Tidak ada pesanan yang cocok dengan pencarian.'
                              : 'Belum ada pesanan.',
                          style: textTheme.bodyLarge,
                        ),
                        if (_hasFilter) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              _status = null;
                              _clearSearch();
                            },
                            child: const Text('Hapus Filter'),
                          ),
                        ],
                      ],
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
                    padding: const EdgeInsets.only(top: 6, bottom: 88),
                    itemCount: orders.length,
                    itemBuilder: (context, index) => OrderTile(
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
