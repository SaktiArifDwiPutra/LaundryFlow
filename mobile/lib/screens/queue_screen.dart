import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../session.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/order_tile.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';

typedef _QueueData = ({OrderSummary summary, List<Order> orders});

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
    final user = currentUser.value;
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
          // 1. Commercial Royal Blue-to-Indigo Hero Header + Integrated Search Bar
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
                // Top Brand & Cashier Row
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.local_laundry_service_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LaundryFlow POS',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                size: 12,
                                color: Color(0xFFBFDBFE),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  user != null
                                      ? 'Kasir: ${user.name}'
                                      : 'Terminal Kasir Utama',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFDBEAFE),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Quick Refresh Action
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: IconButton(
                        tooltip: 'Muat Ulang Antrian',
                        constraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _reload,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Integrated High-Contrast Search Bar inside Hero Header
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
                      hintText: 'Cari nama pelanggan, no. nota (#LDR), atau HP...',
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
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded, size: 18),
                              onPressed: _clearSearch,
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.85)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.white,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.cyanBright,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Operational Body
          Expanded(
            child: FutureBuilder<_QueueData>(
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
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppColors.danger,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Gagal memuat antrian: ${snapshot.error}',
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
                final orders = data.orders;
                final readyCount = summary.byStatus[OrderStatus.ready] ?? 0;
                final activeTotalNominal =
                    orders.fold<int>(0, (sum, o) => sum + o.total);
                final unpaidCount = orders.where((o) => !o.isPaid).length;

                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Operational Bento Overview + Quick Actions + Stage Pipeline
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // A. Colorful 2x2 Operational Bento Grid (Compact when searching)
                              if (_searchQuery.isEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _BentoMetricTile(
                                              label: 'Antrian Aktif',
                                              subtitle: 'Sedang diproses',
                                              value: '${summary.active}',
                                              unit: 'Nota',
                                              icon: Icons.inventory_2_rounded,
                                              accent: AppColors.indigo,
                                              bgTint: isDark
                                                  ? AppColors.indigoDark
                                                      .withValues(alpha: 0.45)
                                                  : AppColors.indigoLight,
                                              isSelected: _status == null,
                                              isDark: isDark,
                                              onTap: () => _setStatus(null),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _BentoMetricTile(
                                              label: 'Siap Diambil',
                                              subtitle: 'Menunggu serah terima',
                                              value: '$readyCount',
                                              unit: 'Nota',
                                              icon: Icons.check_circle_rounded,
                                              accent: AppColors.teal,
                                              bgTint: isDark
                                                  ? AppColors.tealDark
                                                      .withValues(alpha: 0.45)
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
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _BentoMetricTile(
                                              label: 'Layanan Kilat',
                                              subtitle: 'Prioritas Same Day',
                                              value: '${summary.express}',
                                              unit: 'Nota',
                                              icon: Icons.bolt_rounded,
                                              accent: AppColors.warmOrangeBright,
                                              bgTint: isDark
                                                  ? AppColors.warmOrangeDark
                                                      .withValues(alpha: 0.45)
                                                  : AppColors.warmOrangeLight,
                                              isSelected: false,
                                              isDark: isDark,
                                              onTap: () => _setStatus(null),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _BentoMetricTile(
                                              label: summary.overdue > 0
                                                  ? 'Perlu Perhatian'
                                                  : 'Nilai Antrian',
                                              subtitle: summary.overdue > 0
                                                  ? 'Lewat tenggat waktu'
                                                  : '$unpaidCount belum lunas',
                                              value: summary.overdue > 0
                                                  ? '${summary.overdue}'
                                                  : formatRupiah(activeTotalNominal),
                                              unit: summary.overdue > 0 ? 'Telat' : '',
                                              icon: summary.overdue > 0
                                                  ? Icons.warning_amber_rounded
                                                  : Icons.payments_rounded,
                                              accent: summary.overdue > 0
                                                  ? AppColors.danger
                                                  : AppColors.violet,
                                              bgTint: summary.overdue > 0
                                                  ? (isDark
                                                      ? AppColors.dangerDark
                                                          .withValues(alpha: 0.45)
                                                      : AppColors.dangerLight)
                                                  : (isDark
                                                      ? AppColors.violetDark
                                                          .withValues(alpha: 0.45)
                                                      : AppColors.violetLight),
                                              isSelected: false,
                                              isDark: isDark,
                                              onTap: () => _setStatus(null),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // B. Quick Cashier Action Bar
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _QuickActionPill(
                                          icon: Icons.add_circle_rounded,
                                          label: 'Buat Nota',
                                          color: AppColors.primaryBright,
                                          isDark: isDark,
                                          onTap: _newOrder,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _QuickActionPill(
                                          icon: Icons.people_alt_rounded,
                                          label: 'Pelanggan',
                                          color: AppColors.teal,
                                          isDark: isDark,
                                          onTap: () =>
                                              widget.onNavigateTab?.call(3),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _QuickActionPill(
                                          icon: Icons.receipt_long_rounded,
                                          label: 'Semua Nota',
                                          color: AppColors.violet,
                                          isDark: isDark,
                                          onTap: () =>
                                              widget.onNavigateTab?.call(1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // C. Workflow Pipeline Strip (Interactive Stage Selector)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    _PipelineStagePill(
                                      label: 'Semua Tahap',
                                      count: summary.active,
                                      icon: Icons.apps_rounded,
                                      color: AppColors.primaryBright,
                                      isSelected: _status == null,
                                      isDark: isDark,
                                      onTap: () => _setStatus(null),
                                    ),
                                    for (final s in _stages) ...[
                                      const SizedBox(width: 8),
                                      _PipelineStagePill(
                                        label: s.label,
                                        count: summary.byStatus[s] ?? 0,
                                        icon: _stageIcon(s),
                                        color: AppColors.stageStyle(
                                          s,
                                          isDark: isDark,
                                        ).icon,
                                        isSelected: _status == s,
                                        isDark: isDark,
                                        onTap: () => _setStatus(s),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Section Header Row
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryBright,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          _status == null
                                              ? 'Daftar Antrian Aktif'
                                              : 'Tahap: ${_status!.label}',
                                          style: textTheme.titleMedium?.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${orders.length} pesanan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ),

                      // D. Orders Stream / Empty State
                      if (orders.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurfaceElevated
                                        : AppColors.primaryContainerLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.assignment_turned_in_rounded,
                                    size: 34,
                                    color: isDark
                                        ? AppColors.primaryLight
                                        : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Tidak ada pesanan cocok dengan "$_searchQuery"'
                                      : (_status == null
                                          ? 'Antrian Cucian Bersih!'
                                          : 'Belum ada pesanan di tahap ${_status!.label}'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Coba cari menggunakan nama pelanggan atau nomor nota lain.'
                                      : 'Ketuk tombol Transaksi Baru untuk mencatat cucian masuk.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 2, bottom: 88),
                          sliver: SliverList.builder(
                            itemCount: orders.length,
                            itemBuilder: (context, index) => OrderTile(
                              order: orders[index],
                              onTap: () => _openDetail(orders[index]),
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
              // Colored Icon Container
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: value.length > 6 ? 13.5 : 17,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                              letterSpacing: -0.4,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unit.isNotEmpty) ...[
                          const SizedBox(width: 3),
                          Text(
                            unit,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
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

/// Quick Cashier Action Pill
class _QuickActionPill extends StatelessWidget {
  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isDark
                ? color.withValues(alpha: 0.16)
                : color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
