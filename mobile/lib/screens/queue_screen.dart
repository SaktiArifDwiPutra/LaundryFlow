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

enum DashboardPeriod {
  today('Hari Ini'),
  week('7 Hari'),
  month('Bulan Ini'),
  all('Semua');

  const DashboardPeriod(this.label);
  final String label;
}

enum DashboardListFilter {
  none,
  todayOnly,
  paidOnly,
  unpaidOnly,
  readyOnly,
}

typedef _DashboardData = ({
  OrderSummary summary,
  List<Order> allOrders,
});

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

typedef DashboardScreen = QueueScreen;

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
  DashboardPeriod _selectedPeriod = DashboardPeriod.today;
  DashboardListFilter _activeListFilter = DashboardListFilter.none;
  String _searchQuery = '';
  late Future<_DashboardData> _future;

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

  Future<_DashboardData> _load() async {
    final results = await Future.wait<Object>([
      orderRepository.summary(),
      orderRepository.list(
        q: _searchQuery,
        sort: OrderSort.createdAt,
      ),
    ]);
    return (
      summary: results[0] as OrderSummary,
      allOrders: results[1] as List<Order>,
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
      _activeListFilter = DashboardListFilter.none;
    });
  }

  void _setListFilter(DashboardListFilter filter) {
    setState(() {
      if (_activeListFilter == filter) {
        _activeListFilter = DashboardListFilter.none;
      } else {
        _activeListFilter = filter;
        _status = null;
      }
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
    _activeListFilter = DashboardListFilter.none;
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

  bool _isSameDay(DateTime a, DateTime b) {
    final aLocal = a.toLocal();
    final bLocal = b.toLocal();
    return aLocal.year == bLocal.year &&
        aLocal.month == bLocal.month &&
        aLocal.day == bLocal.day;
  }

  bool _isOrderInPeriod(Order order, DashboardPeriod period, DateTime now) {
    final created = order.createdAt.toLocal();
    switch (period) {
      case DashboardPeriod.today:
        return _isSameDay(created, now);
      case DashboardPeriod.week:
        return now.difference(created).inDays < 7 && !now.difference(created).isNegative;
      case DashboardPeriod.month:
        return created.year == now.year && created.month == now.month;
      case DashboardPeriod.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = currentUser.value;
    final topPadding = MediaQuery.of(context).padding.top;
    final now = DateTime.now();

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
          // 1. Commercial Royal Blue-to-Indigo Hero Header + Integrated Search & Date
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
                        Icons.local_laundry_service_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.teal,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'SHIFT AKTIF',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: Color(0xFFBFDBFE),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatDateIndonesian(now),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFDBEAFE),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                user != null ? '• ${user.name}' : '',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFFBFDBFE),
                                ),
                                overflow: TextOverflow.ellipsis,
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
                        tooltip: 'Muat Ulang Data',
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
                      hintText: 'Cari nota (#LDR), nama pelanggan, atau HP...',
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

          // 2. Main Dashboard & Operational Body
          Expanded(
            child: FutureBuilder<_DashboardData>(
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
                            'Gagal memuat dashboard: ${snapshot.error}',
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
                final allOrders = data.allOrders;

                // 1. Calculate Period Statistics (Hari Ini, 7 Hari, Bulan Ini, Semua)
                final periodOrders = allOrders
                    .where((o) => _isOrderInPeriod(o, _selectedPeriod, now))
                    .toList();
                final periodOrderCount = periodOrders.length;
                final periodTotalRevenue =
                    periodOrders.fold<int>(0, (sum, o) => sum + o.total);
                final periodPaidRevenue = periodOrders.fold<int>(
                    0, (sum, o) => sum + (o.isPaid ? o.total : o.amountPaid));
                final periodUnpaidRevenue = periodOrders.fold<int>(
                    0,
                    (sum, o) =>
                        sum +
                        (o.isPaid
                            ? 0
                            : (o.amountDue > 0 ? o.amountDue : o.total)));
                final periodPaidCount =
                    periodOrders.where((o) => o.isPaid).length;
                final periodUnpaidCount =
                    periodOrderCount - periodPaidCount;
                final paymentCollectionRate = periodOrderCount == 0
                    ? 1.0
                    : (periodPaidCount / periodOrderCount).clamp(0.0, 1.0);

                // 2. Operational active counts
                final readyCount = summary.byStatus[OrderStatus.ready] ?? 0;

                // 3. Determine which orders to display in the list
                List<Order> displayedOrders;
                if (_searchQuery.isNotEmpty) {
                  displayedOrders = allOrders;
                } else if (_activeListFilter == DashboardListFilter.todayOnly) {
                  displayedOrders = allOrders.where((o) => _isSameDay(o.createdAt, now)).toList();
                } else if (_activeListFilter == DashboardListFilter.paidOnly) {
                  displayedOrders = allOrders.where((o) => o.isPaid).toList();
                } else if (_activeListFilter == DashboardListFilter.unpaidOnly) {
                  displayedOrders = allOrders.where((o) => !o.isPaid).toList();
                } else if (_activeListFilter == DashboardListFilter.readyOnly) {
                  displayedOrders = allOrders.where((o) => o.status == OrderStatus.ready).toList();
                } else if (_status != null) {
                  displayedOrders = allOrders.where((o) => o.status == _status).toList();
                } else {
                  // Default view: active laundry queue (not completed yet)
                  final active = allOrders
                      .where((o) =>
                          o.status != OrderStatus.completed &&
                          o.status != OrderStatus.unknown)
                      .toList();
                  displayedOrders = active.isNotEmpty ? active : allOrders;
                }

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
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ==========================================
                              // SECTION A: DASHBOARD INVOICE & KEUANGAN HARI INI
                              // ==========================================
                              if (_searchQuery.isEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                        width: 1.2,
                                      ),
                                      boxShadow: AppColors.cardShadow(isDark: isDark),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Title & Period Selector Row
                                        Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBright.withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.analytics_rounded,
                                                color: AppColors.primaryBright,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Statistik Invoice & Omzet',
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Rekap transaksi nota per periode',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      color: AppColors.neutral,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Period Selector Pills
                                            Container(
                                              padding: const EdgeInsets.all(2.5),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors.darkSurfaceElevated
                                                    : AppColors.lightSurfaceElevated,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  for (final p in DashboardPeriod.values)
                                                    _PeriodPillButton(
                                                      label: p.label,
                                                      selected: _selectedPeriod == p,
                                                      onTap: () => setState(() => _selectedPeriod = p),
                                                      isDark: isDark,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // 4 Financial & Invoice Bento Cards
                                        Row(
                                          children: [
                                            // 1. Total Invoices Today
                                            Expanded(
                                              child: _ExecutiveKpiCard(
                                                title: 'Invoice ${_selectedPeriod.label}',
                                                value: '$periodOrderCount Nota',
                                                subtitle: _selectedPeriod == DashboardPeriod.today
                                                    ? 'Transaksi hari ini'
                                                    : 'Total nota terbit',
                                                icon: Icons.receipt_long_rounded,
                                                accent: AppColors.primaryBright,
                                                bgTint: isDark
                                                    ? AppColors.primaryContainerDark.withValues(alpha: 0.5)
                                                    : AppColors.primaryContainerLight,
                                                isSelected: _activeListFilter == DashboardListFilter.todayOnly,
                                                onTap: () => _setListFilter(DashboardListFilter.todayOnly),
                                                isDark: isDark,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // 2. Total Revenue Today
                                            Expanded(
                                              child: _ExecutiveKpiCard(
                                                title: 'Total Omzet',
                                                value: formatRupiah(periodTotalRevenue),
                                                subtitle: 'Nilai seluruh tagihan',
                                                icon: Icons.account_balance_wallet_rounded,
                                                accent: AppColors.violet,
                                                bgTint: isDark
                                                    ? AppColors.violetDark.withValues(alpha: 0.45)
                                                    : AppColors.violetLight,
                                                isSelected: false,
                                                onTap: () => _setListFilter(DashboardListFilter.none),
                                                isDark: isDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            // 3. Paid Invoices (Cash in)
                                            Expanded(
                                              child: _ExecutiveKpiCard(
                                                title: 'Faktur Lunas',
                                                value: formatRupiah(periodPaidRevenue),
                                                subtitle: '$periodPaidCount nota lunas',
                                                icon: Icons.verified_rounded,
                                                accent: AppColors.teal,
                                                bgTint: isDark
                                                    ? AppColors.tealDark.withValues(alpha: 0.45)
                                                    : AppColors.tealLight,
                                                isSelected: _activeListFilter == DashboardListFilter.paidOnly,
                                                onTap: () => _setListFilter(DashboardListFilter.paidOnly),
                                                isDark: isDark,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // 4. Unpaid / Due Invoices
                                            Expanded(
                                              child: _ExecutiveKpiCard(
                                                title: 'Belum Lunas',
                                                value: formatRupiah(periodUnpaidRevenue),
                                                subtitle: '$periodUnpaidCount nota belum lunas',
                                                icon: Icons.pending_actions_rounded,
                                                accent: AppColors.warmOrangeBright,
                                                bgTint: isDark
                                                    ? AppColors.warmOrangeDark.withValues(alpha: 0.45)
                                                    : AppColors.warmOrangeLight,
                                                isSelected: _activeListFilter == DashboardListFilter.unpaidOnly,
                                                onTap: () => _setListFilter(DashboardListFilter.unpaidOnly),
                                                isDark: isDark,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Payment Collection Progress Strip
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.darkSurfaceElevated
                                                : AppColors.lightSurfaceElevated,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Tingkat Pelunasan Tagihan',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: isDark
                                                                ? AppColors.darkTextSecondary
                                                                : AppColors.lightTextSecondary,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${(paymentCollectionRate * 100).toStringAsFixed(0)}% Lunas',
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.w800,
                                                            color: AppColors.teal,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 5),
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: LinearProgressIndicator(
                                                        value: paymentCollectionRate,
                                                        minHeight: 6,
                                                        backgroundColor: isDark
                                                            ? AppColors.darkBorder
                                                            : const Color(0xFFE2E8F0),
                                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                                          AppColors.teal,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // ==========================================
                                // SECTION B: OPERATIONAL WORKFLOW METRICS (2x2)
                                // ==========================================
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBright,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Status Alur Cucian Aktif',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
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
                                                  ? AppColors.indigoDark.withValues(alpha: 0.45)
                                                  : AppColors.indigoLight,
                                              isSelected: _status == null && _activeListFilter == DashboardListFilter.none,
                                              isDark: isDark,
                                              onTap: () {
                                                setState(() {
                                                  _status = null;
                                                  _activeListFilter = DashboardListFilter.none;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _BentoMetricTile(
                                              label: 'Siap Diambil',
                                              subtitle: 'Selesai dicuci',
                                              value: '$readyCount',
                                              unit: 'Nota',
                                              icon: Icons.check_circle_rounded,
                                              accent: AppColors.teal,
                                              bgTint: isDark
                                                  ? AppColors.tealDark.withValues(alpha: 0.45)
                                                  : AppColors.tealLight,
                                              isSelected: _status == OrderStatus.ready,
                                              isDark: isDark,
                                              onTap: () => _setStatus(OrderStatus.ready),
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
                                                  ? AppColors.warmOrangeDark.withValues(alpha: 0.45)
                                                  : AppColors.warmOrangeLight,
                                              isSelected: false,
                                              isDark: isDark,
                                              onTap: () {
                                                setState(() {
                                                  _status = null;
                                                  _activeListFilter = DashboardListFilter.none;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _BentoMetricTile(
                                              label: summary.overdue > 0
                                                  ? 'Perlu Perhatian'
                                                  : 'Siap Diantar',
                                              subtitle: summary.overdue > 0
                                                  ? 'Lewat tenggat waktu'
                                                  : 'Antar ke pelanggan',
                                              value: summary.overdue > 0
                                                  ? '${summary.overdue}'
                                                  : '${summary.byStatus[OrderStatus.outForDelivery] ?? 0}',
                                              unit: 'Nota',
                                              icon: summary.overdue > 0
                                                  ? Icons.warning_amber_rounded
                                                  : Icons.delivery_dining_rounded,
                                              accent: summary.overdue > 0
                                                  ? AppColors.danger
                                                  : AppColors.cyan,
                                              bgTint: summary.overdue > 0
                                                  ? (isDark
                                                      ? AppColors.dangerDark.withValues(alpha: 0.45)
                                                      : AppColors.dangerLight)
                                                  : (isDark
                                                      ? AppColors.cyanDark.withValues(alpha: 0.45)
                                                      : AppColors.cyanLight),
                                              isSelected: _status == OrderStatus.outForDelivery,
                                              isDark: isDark,
                                              onTap: () => _setStatus(OrderStatus.outForDelivery),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ==========================================
                                // SECTION C: QUICK CASHIER ACTIONS
                                // ==========================================
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
                                          onTap: () => widget.onNavigateTab?.call(3),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _QuickActionPill(
                                          icon: Icons.receipt_long_rounded,
                                          label: 'Semua Nota',
                                          color: AppColors.violet,
                                          isDark: isDark,
                                          onTap: () => widget.onNavigateTab?.call(1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // ==========================================
                              // SECTION D: WORKFLOW PIPELINE STRIP
                              // ==========================================
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
                                      isSelected: _status == null && _activeListFilter == DashboardListFilter.none,
                                      isDark: isDark,
                                      onTap: () {
                                        setState(() {
                                          _status = null;
                                          _activeListFilter = DashboardListFilter.none;
                                        });
                                      },
                                    ),
                                    for (final s in _stages) ...[
                                      const SizedBox(width: 8),
                                      _PipelineStagePill(
                                        label: s.label,
                                        count: summary.byStatus[s] ?? 0,
                                        icon: _stageIcon(s),
                                        color: AppColors.stageStyle(s, isDark: isDark).icon,
                                        isSelected: _status == s,
                                        isDark: isDark,
                                        onTap: () => _setStatus(s),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // ==========================================
                              // SECTION E: LIST HEADER & ACTIVE FILTER CHIP
                              // ==========================================
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          _activeListFilter == DashboardListFilter.todayOnly
                                              ? 'Daftar Invoice Hari Ini'
                                              : (_activeListFilter == DashboardListFilter.paidOnly
                                                  ? 'Nota Lunas Terbayar'
                                                  : (_activeListFilter == DashboardListFilter.unpaidOnly
                                                      ? 'Nota Belum Lunas'
                                                      : (_status == null
                                                          ? 'Daftar Antrian Cucian'
                                                          : 'Tahap: ${_status!.label}'))),
                                          style: textTheme.titleMedium?.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (_activeListFilter != DashboardListFilter.none || _status != null)
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _status = null;
                                                _activeListFilter = DashboardListFilter.none;
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.dangerLight,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.close_rounded, size: 12, color: AppColors.danger),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'Reset',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.danger,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        Text(
                                          '${displayedOrders.length} nota',
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
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ),

                      // ==========================================
                      // SECTION F: DIE-CUT NOTCHED POS ORDERS LIST
                      // ==========================================
                      if (displayedOrders.isEmpty)
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
                                    Icons.receipt_long_rounded,
                                    size: 34,
                                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Tidak ada pesanan cocok dengan "$_searchQuery"'
                                      : (_activeListFilter == DashboardListFilter.todayOnly
                                          ? 'Belum ada invoice baru yang dibuat hari ini.'
                                          : (_status == null
                                              ? 'Antrian Cucian Bersih!'
                                              : 'Belum ada pesanan di tahap ${_status!.label}')),
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
                                const SizedBox(height: 14),
                                if (_activeListFilter != DashboardListFilter.none || _status != null)
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _status = null;
                                        _activeListFilter = DashboardListFilter.none;
                                      });
                                    },
                                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                                    label: const Text('Tampilkan Semua Antrian'),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 2, bottom: 88),
                          sliver: SliverList.builder(
                            itemCount: displayedOrders.length,
                            itemBuilder: (context, index) => OrderTile(
                              order: displayedOrders[index],
                              onTap: () => _openDetail(displayedOrders[index]),
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

/// Executive KPI Card for Today's Invoices & Financials
class _ExecutiveKpiCard extends StatelessWidget {
  const _ExecutiveKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.bgTint,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color bgTint;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: isDark ? 0.22 : 0.10)
                : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? accent
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: bgTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: value.length > 10 ? 14 : 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  letterSpacing: -0.3,
                  fontFeatures: const [
                    FontFeature.tabularFigures(),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? accent
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Period Pill Button (Hari Ini, 7 Hari, Bulan Ini, Semua)
class _PeriodPillButton extends StatelessWidget {
  const _PeriodPillButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.primaryBright : AppColors.primary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
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
