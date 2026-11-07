import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../session.dart';
import '../theme/app_colors.dart';
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
      SnackBar(content: Text('Pesanan ${created.number} berhasil dibuat')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = currentUser.value;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard Operasional'),
            if (user != null)
              Text(
                'Kasir: ${user.name}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
          ],
        ),
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
      body: FutureBuilder<_QueueData>(
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
                      'Gagal memuat antrian: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge,
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

          final data = snapshot.data!;
          final summary = data.summary;
          final orders = data.orders;
          final readyCount = summary.byStatus[OrderStatus.ready] ?? 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Operational KPI Cards Grid (4 Essential Metrics)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Total Aktif',
                        value: summary.active,
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.primary,
                        isSelected: _status == null,
                        onTap: () => _setStatus(null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KpiCard(
                        title: 'Siap Diambil',
                        value: readyCount,
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                        isSelected: _status == OrderStatus.ready,
                        onTap: () => _setStatus(OrderStatus.ready),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Terlambat',
                        value: summary.overdue,
                        icon: Icons.alarm_outlined,
                        color: summary.overdue > 0 ? AppColors.danger : AppColors.neutral,
                        isSelected: false,
                        onTap: () => _setStatus(null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KpiCard(
                        title: 'Express / Sameday',
                        value: summary.express,
                        icon: Icons.bolt,
                        color: AppColors.warning,
                        isSelected: false,
                        onTap: () => _setStatus(null),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips Carousel
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        avatar: const Icon(Icons.all_inbox, size: 16),
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

              // Sub-header Context
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _status == null
                          ? 'Daftar Antrian Aktif (${orders.length})'
                          : '${_status!.label} (${orders.length})',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Urut: Tenggat Terdekat',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Orders List with Pull-to-Refresh
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: orders.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 64),
                            Icon(
                              Icons.fact_check_outlined,
                              size: 56,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                _status == null
                                    ? 'Tidak ada pesanan aktif saat ini.'
                                    : 'Tidak ada pesanan dengan status ${_status!.label}.',
                                style: textTheme.bodyMedium,
                              ),
                            ),
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

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: isDark ? 0.4 : 0.25),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : color,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
