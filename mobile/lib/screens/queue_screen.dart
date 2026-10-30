import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../session.dart';
import '../widgets/order_tile.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';

typedef _QueueData = ({OrderSummary summary, List<Order> orders});

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  static const _stages = <OrderStatus>[
    OrderStatus.received,
    OrderStatus.washing,
    OrderStatus.drying,
    OrderStatus.ironing,
    OrderStatus.ready,
    OrderStatus.outForDelivery,
  ];

  OrderStatus? _status;
  late Future<_QueueData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_QueueData> _load() async {
    final results = await Future.wait<Object>([
      orderRepository.summary(),
      orderRepository.list(
        status: _status,
        activeOnly: true,
        sort: OrderSort.dueAt,
      ),
    ]);
    return (
      summary: results[0] as OrderSummary,
      orders: results[1] as List<Order>,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _setStatus(OrderStatus? status) {
    _status = status;
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
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pesanan ${created.number} dibuat')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrian'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authRepository.logout();
              currentUser.value = null;
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        icon: const Icon(Icons.add),
        label: const Text('Pesanan Baru'),
      ),
      body: FutureBuilder<_QueueData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat antrian: ${snapshot.error}'),
            );
          }

          final data = snapshot.data!;
          final summary = data.summary;
          final orders = data.orders;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Aktif',
                        value: summary.active,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: 'Terlambat',
                        value: summary.overdue,
                        color: summary.overdue > 0 ? Colors.red : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: 'Express',
                        value: summary.express,
                        color: Colors.orange,
                      ),
                    ),
                  ],
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
                        label: Text('Semua (${summary.active})'),
                        selected: _status == null,
                        onSelected: (_) => _setStatus(null),
                      ),
                    ),
                    for (final s in _stages)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('${s.label} (${summary.byStatus[s] ?? 0})'),
                          selected: _status == s,
                          onSelected: (_) => _setStatus(s),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Diurutkan dari tenggat terdekat',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: orders.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            Center(child: Text('Tidak ada pesanan di antrian.')),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 4, bottom: 88),
                          itemCount: orders.length,
                          itemBuilder: (context, index) => OrderTile(
                            order: orders[index],
                            onTap: () => _openDetail(orders[index]),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}