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
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_laundry_service,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'LaundryFlow',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.successDark.withValues(alpha: 0.4)
                            : AppColors.successLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ONLINE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF86EFAC) : AppColors.successText,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  user != null ? 'Kasir: ${user.name}' : 'Kasir Aktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang Antrian',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        icon: const Icon(Icons.add_shopping_cart, size: 20),
        label: const Text(
          'Pesanan Baru',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        elevation: 4,
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
              // Operational KPI Bento Cards (4 Essential Metrics)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Total Antrian',
                        value: summary.active,
                        subtitle: 'Semua proses aktif',
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.primary,
                        isSelected: _status == null,
                        onTap: () => _setStatus(null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiCard(
                        title: 'Siap Diambil',
                        value: readyCount,
                        subtitle: 'Siap diserahkan',
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Kilat / Express',
                        value: summary.express,
                        subtitle: 'Prioritas hari ini',
                        icon: Icons.bolt,
                        color: AppColors.warning,
                        isSelected: false,
                        onTap: () => _setStatus(null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiCard(
                        title: 'Perlu Perhatian',
                        value: summary.overdue,
                        subtitle: summary.overdue > 0 ? 'Melewati tenggat' : 'Semua tepat waktu',
                        icon: Icons.alarm_outlined,
                        color: summary.overdue > 0 ? AppColors.danger : AppColors.neutral,
                        isSelected: false,
                        onTap: () => _setStatus(null),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips Bar with Stage Count Badges
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _status == null
                          ? 'Daftar Antrian (${orders.length})'
                          : '${_status!.label} (${orders.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.sort, size: 14, color: AppColors.neutral),
                        const SizedBox(width: 4),
                        Text(
                          'Tenggat Terdekat',
                          style: textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
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
                            const SizedBox(height: 56),
                            Center(
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurfaceElevated
                                      : AppColors.lightSurfaceElevated,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 40,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                _status == null
                                    ? 'Tidak ada antrian cucian aktif'
                                    : 'Tidak ada cucian dengan status ${_status!.label}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'Sentuh tombol di bawah untuk mencatat pesanan baru.',
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 2, bottom: 88),
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
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? color
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: AppColors.cardShadow(isDark: isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : (isSelected ? color : AppColors.lightTextPrimary),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
