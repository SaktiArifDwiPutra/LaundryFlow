import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../theme/app_colors.dart';
import '../widgets/order_tile.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';

typedef _QueueData = ({
  OrderSummary summary,
  List<Order> orders,
});

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

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
  bool _expressOnly = false;
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
      _expressOnly = false;
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
    _expressOnly = false;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pesanan ${created.number} berhasil dibuat')),
    );
  }

  IconData _stageIcon(OrderStatus s) {
    return switch (s) {
      OrderStatus.received => Icons.inventory_2_rounded,
      OrderStatus.washing => Icons.local_laundry_service_rounded,
      OrderStatus.drying => Icons.wb_sunny_rounded,
      OrderStatus.ironing => Icons.iron_rounded,
      OrderStatus.ready => Icons.check_circle_rounded,
      OrderStatus.outForDelivery => Icons.delivery_dining_rounded,
      _ => Icons.circle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        backgroundColor: AppColors.primaryBright,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: const Text(
          'Transaksi Baru',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
        elevation: 5,
      ),
      body: Column(
        children: [
          // 1. Commercial Royal Blue-to-Indigo Hero Header + Integrated Search
          Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 14),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient(isDark: isDark),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : AppColors.primary)
                      .withValues(alpha: isDark ? 0.45 : 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Antrean Cucian',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pantau alur pengerjaan cucian aktif',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFDBEAFE),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Integrated Search Bar inside Hero Header
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari antrean nota (#LDR), nama, atau HP...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: isDark
                            ? AppColors.cyanLight
                            : AppColors.primaryBright,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          width: 1.1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryBright,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Body: Operational Metrics, Pipeline Stages & Order Cards
          Expanded(
            child: FutureBuilder<_QueueData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppColors.danger,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Gagal memuat antrean: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
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
                var orders = data.orders;

                if (_expressOnly) {
                  orders = orders.where((o) => o.isExpress).toList();
                }

                final readyCount = summary.byStatus[OrderStatus.ready] ?? 0;
                final deliveryCount =
                    summary.byStatus[OrderStatus.outForDelivery] ?? 0;
                final expressCount =
                    orders.where((o) => o.isExpress).length;

                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Operational 4-Bento Metrics
                              if (_searchQuery.isEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _BentoMetricTile(
                                          label: 'Antrian Aktif',
                                          subtitle: 'Sedang dikerjakan',
                                          value: '${summary.active}',
                                          unit: 'Cucian',
                                          icon: Icons.layers_rounded,
                                          accent: AppColors.primaryBright,
                                          bgTint: isDark
                                              ? AppColors.primaryContainerDark
                                                  .withValues(alpha: 0.5)
                                              : AppColors.primaryContainerLight,
                                          isSelected: _status == null &&
                                              !_expressOnly,
                                          isDark: isDark,
                                          onTap: () => _setStatus(null),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _BentoMetricTile(
                                          label: 'Siap Diambil',
                                          subtitle: 'Tunggu pelanggan',
                                          value: '$readyCount',
                                          unit: 'Siap',
                                          icon: Icons.check_circle_rounded,
                                          accent: AppColors.teal,
                                          bgTint: isDark
                                              ? AppColors.tealDark
                                                  .withValues(alpha: 0.5)
                                              : AppColors.tealLight,
                                          isSelected:
                                              _status == OrderStatus.ready,
                                          isDark: isDark,
                                          onTap: () =>
                                              _setStatus(OrderStatus.ready),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _BentoMetricTile(
                                          label: 'Layanan Kilat',
                                          subtitle: 'Prioritas Express',
                                          value: '$expressCount',
                                          unit: 'Kilat',
                                          icon: Icons.bolt_rounded,
                                          accent: AppColors.warmOrange,
                                          bgTint: isDark
                                              ? AppColors.warmOrangeDark
                                                  .withValues(alpha: 0.45)
                                              : AppColors.warmOrangeLight,
                                          isSelected: _expressOnly,
                                          isDark: isDark,
                                          onTap: () {
                                            setState(() {
                                              _expressOnly = !_expressOnly;
                                              if (_expressOnly) _status = null;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _BentoMetricTile(
                                          label: 'Siap Diantar',
                                          subtitle: 'Alur Delivery',
                                          value: '$deliveryCount',
                                          unit: 'Antar',
                                          icon: Icons.delivery_dining_rounded,
                                          accent: AppColors.cyan,
                                          bgTint: isDark
                                              ? AppColors.cyanDark
                                                  .withValues(alpha: 0.45)
                                              : AppColors.cyanLight,
                                          isSelected: _status ==
                                              OrderStatus.outForDelivery,
                                          isDark: isDark,
                                          onTap: () => _setStatus(
                                              OrderStatus.outForDelivery),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Workflow Stage Pipeline Filter Strip
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: AppColors.cyan,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Tahap Alur Pengerjaan',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _PipelineStagePill(
                                              label: 'Semua',
                                              count: summary.active,
                                              icon: Icons.all_inclusive_rounded,
                                              color: AppColors.primaryBright,
                                              isSelected: _status == null &&
                                                  !_expressOnly,
                                              isDark: isDark,
                                              onTap: () => _setStatus(null),
                                            ),
                                            const SizedBox(width: 8),
                                            for (final s in _stages) ...[
                                              _PipelineStagePill(
                                                label: s.label,
                                                count:
                                                    summary.byStatus[s] ?? 0,
                                                icon: _stageIcon(s),
                                                color: switch (s) {
                                                  OrderStatus.received =>
                                                    AppColors.neutral,
                                                  OrderStatus.washing =>
                                                    AppColors.primaryBright,
                                                  OrderStatus.drying =>
                                                    AppColors.warmOrange,
                                                  OrderStatus.ironing =>
                                                    AppColors.violet,
                                                  OrderStatus.ready =>
                                                    AppColors.teal,
                                                  OrderStatus.outForDelivery =>
                                                    AppColors.cyan,
                                                  _ => AppColors.neutral,
                                                },
                                                isSelected: _status == s,
                                                isDark: isDark,
                                                onTap: () => _setStatus(s),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              // List Header
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryBright,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'Hasil Pencarian: ${orders.length} Antrean'
                                              : _status != null
                                                  ? 'Antrean ${_status!.label} (${orders.length})'
                                                  : _expressOnly
                                                      ? 'Antrean Layanan Kilat (${orders.length})'
                                                      : 'Seluruh Antrean Aktif (${orders.length})',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_status != null || _expressOnly)
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                        ),
                                        onPressed: () => _setStatus(null),
                                        child: const Text('Tampilkan Semua'),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),

                      // Order Items List
                      if (orders.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: (isDark
                                              ? AppColors.darkSurfaceElevated
                                              : AppColors.lightSurfaceElevated)
                                          .withValues(alpha: 0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 32,
                                      color: AppColors.teal,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Tidak ditemukan antrean "$_searchQuery"'
                                        : 'Tidak ada antrean cucian aktif',
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Semua pakaian sudah selesai diproses.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.neutral,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final order = orders[index];
                                return OrderTile(
                                  order: order,
                                  onTap: () => _openDetail(order),
                                );
                              },
                              childCount: orders.length,
                            ),
                          ),
                        ),
                    ],
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

/// Tactile Colorful Bento Metric Card (2x2 Grid)
class _BentoMetricTile extends StatelessWidget {
  const _BentoMetricTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accent,
    required this.bgTint,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final String value;
  final String unit;
  final IconData icon;
  final Color accent;
  final Color bgTint;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? accent
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: AppColors.cardShadow(isDark: isDark),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
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
      ),
    );
  }
}

/// Interactive Stage Pill in Workflow Pipeline Strip
class _PipelineStagePill extends StatelessWidget {
  const _PipelineStagePill({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7.5),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryActionGradient : null,
            color: isSelected
                ? null
                : (isDark ? AppColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? AppColors.glowShadow(AppColors.primaryBright, isDark: isDark)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.22)
                      : color.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
