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

  final _searchController = TextEditingController();
  OrderStatus? _status;
  String _searchQuery = '';
  late Future<_QueueData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_QueueData> _load() async {
    final results = await Future.wait<Object>([
      orderRepository.summary(),
      orderRepository.list(
        status: _status,
        q: _searchQuery,
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
    setState(() {
      _status = status;
      _future = _load();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
      _future = _load();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
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
      // 1. Ultra-Clean & Compact App Bar (Online text removed as requested)
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_laundry_service,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LaundryFlow',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                Text(
                  user != null ? 'Kasir: ${user.name}' : 'Kasir Laundry',
                  style: TextStyle(
                    fontSize: 11,
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
            tooltip: 'Muat Ulang',
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _reload,
          ),
          const SizedBox(width: 4),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Pesanan Baru',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        elevation: 3,
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
                    const Icon(Icons.error_outline, size: 44, color: AppColors.danger),
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
              const SizedBox(height: 8),

              // 2. Space-Efficient Single-Row KPI Metric Bar (Compact ~44px height)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _CompactKpiChip(
                      label: 'Antrian',
                      value: summary.active,
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.primary,
                      isSelected: _status == null,
                      isDark: isDark,
                      onTap: () => _setStatus(null),
                    ),
                    const SizedBox(width: 8),
                    _CompactKpiChip(
                      label: 'Siap Diambil',
                      value: readyCount,
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                      isSelected: _status == OrderStatus.ready,
                      isDark: isDark,
                      onTap: () => _setStatus(OrderStatus.ready),
                    ),
                    const SizedBox(width: 8),
                    _CompactKpiChip(
                      label: 'Kilat',
                      value: summary.express,
                      icon: Icons.bolt,
                      color: AppColors.warning,
                      isSelected: false,
                      isDark: isDark,
                      onTap: () => _setStatus(null),
                    ),
                    const SizedBox(width: 8),
                    _CompactKpiChip(
                      label: 'Terlambat',
                      value: summary.overdue,
                      icon: Icons.alarm_outlined,
                      color: summary.overdue > 0 ? AppColors.danger : AppColors.neutral,
                      isSelected: false,
                      isDark: isDark,
                      onTap: () => _setStatus(null),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 3. Compact Search Bar in Queue (Comfortable searching, no cramped feeling)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari nama, no. nota, atau nomor HP...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: _clearSearch,
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // 4. Compact Stage Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('Semua (${summary.active})'),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: _status == null ? FontWeight.w700 : FontWeight.w500,
                        ),
                        selected: _status == null,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => _setStatus(null),
                      ),
                    ),
                    for (final s in _stages)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('${s.label} (${summary.byStatus[s] ?? 0})'),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: _status == s ? FontWeight.w700 : FontWeight.w500,
                          ),
                          selected: _status == s,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => _setStatus(s),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // 5. Orders Stream / List (Takes up 75%+ of viewport!)
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
                            const SizedBox(height: 48),
                            Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurfaceElevated
                                      : AppColors.lightSurfaceElevated,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 32,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'Tidak ada pesanan cocok dengan "$_searchQuery"'
                                    : (_status == null
                                        ? 'Tidak ada antrian cucian aktif'
                                        : 'Tidak ada pesanan dengan status ${_status!.label}'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'Coba gunakan kata kunci nama atau nomor lain.'
                                    : 'Pesanan baru akan otomatis muncul di sini.',
                                style: textTheme.bodySmall?.copyWith(fontSize: 12),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 2, bottom: 84),
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

/// Compact Metric Chip (~38px height) saving substantial screen real estate
class _CompactKpiChip extends StatelessWidget {
  const _CompactKpiChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark ? AppColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: AppColors.cardShadow(isDark: isDark),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
