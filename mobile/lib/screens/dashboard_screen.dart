import 'package:flutter/material.dart';

import '../models/order.dart';
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
  periodInvoices,
  paidOnly,
  unpaidOnly,
}

typedef _DashboardData = ({
  OrderSummary summary,
  List<Order> allOrders,
});

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
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

  void _setListFilter(DashboardListFilter filter) {
    setState(() {
      if (_activeListFilter == filter) {
        _activeListFilter = DashboardListFilter.none;
      } else {
        _activeListFilter = filter;
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
    _activeListFilter = DashboardListFilter.none;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pesanan ${created.number} berhasil dibuat')),
    );
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
        return now.difference(created).inDays < 7 &&
            !now.difference(created).isNegative;
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
                // Top Brand & Cashier Row (Clean: NO "SHIFT AKTIF" badge)
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
                    const SizedBox(width: 12),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 11.5,
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
                              if (user != null) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '• ${user.name}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFBFDBFE),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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

          // 2. Main Content Body
          Expanded(
            child: FutureBuilder<_DashboardData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
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

                // 1. Calculate Period Statistics
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

                final activeQueueCount = summary.active;

                // 2. Determine which orders to display in the list below
                List<Order> displayedOrders;
                String activeFilterLabel = '';
                if (_searchQuery.isNotEmpty) {
                  displayedOrders = allOrders;
                  activeFilterLabel = 'Hasil Pencarian "$_searchQuery"';
                } else if (_activeListFilter ==
                    DashboardListFilter.periodInvoices) {
                  displayedOrders = periodOrders;
                  activeFilterLabel =
                      'Invoice ${_selectedPeriod.label} ($periodOrderCount Nota)';
                } else if (_activeListFilter == DashboardListFilter.paidOnly) {
                  displayedOrders =
                      periodOrders.where((o) => o.isPaid).toList();
                  activeFilterLabel =
                      'Faktur Lunas ${_selectedPeriod.label} (${displayedOrders.length} Nota)';
                } else if (_activeListFilter == DashboardListFilter.unpaidOnly) {
                  displayedOrders =
                      periodOrders.where((o) => !o.isPaid).toList();
                  activeFilterLabel =
                      'Tagihan Belum Lunas (${displayedOrders.length} Nota)';
                } else {
                  // Default view: latest orders of the selected period or all orders
                  displayedOrders =
                      periodOrders.isNotEmpty ? periodOrders : allOrders;
                  activeFilterLabel = periodOrders.isNotEmpty
                      ? 'Daftar Nota ${_selectedPeriod.label} (${displayedOrders.length} Nota)'
                      : 'Transaksi Terbaru (${displayedOrders.length} Nota)';
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
                          padding: const EdgeInsets.only(top: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ==========================================
                              // SECTION A: DASHBOARD INVOICE & KEUANGAN
                              // ==========================================
                              if (_searchQuery.isEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurface
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                        width: 1.2,
                                      ),
                                      boxShadow:
                                          AppColors.cardShadow(isDark: isDark),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Row 1: Title & Icon (Spanning horizontally without wrapping)
                                        Row(
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBright
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.analytics_rounded,
                                                color: AppColors.primaryBright,
                                                size: 19,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Statistik Invoice & Omzet',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: -0.2,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    'Rekap performa transaksi dan pendapatan kasir',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.neutral,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Row 2: Clean Full-Width Period Filter Bar (Tidy & Balanced)
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.darkSurfaceElevated
                                                : AppColors
                                                    .lightSurfaceElevated,
                                            borderRadius:
                                                BorderRadius.circular(11),
                                            border: Border.all(
                                              color: isDark
                                                  ? AppColors.darkBorder
                                                  : AppColors.lightBorder,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              for (final p
                                                  in DashboardPeriod.values)
                                                Expanded(
                                                  child: _PeriodPillButton(
                                                    label: p.label,
                                                    selected:
                                                        _selectedPeriod == p,
                                                    onTap: () {
                                                      setState(() {
                                                        _selectedPeriod = p;
                                                        _activeListFilter =
                                                            DashboardListFilter
                                                                .none;
                                                      });
                                                    },
                                                    isDark: isDark,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 12),

                                        // 4 Financial & Invoice Bento Cards
                                        Row(
                                          children: [
                                            // 1. Total Invoices for Period
                                            Expanded(
                                              child: _ExecutiveKpiCard(
                                                title:
                                                    'Invoice ${_selectedPeriod.label}',
                                                value: '$periodOrderCount Nota',
                                                subtitle: _selectedPeriod ==
                                                        DashboardPeriod.today
                                                    ? 'Transaksi hari ini'
                                                    : 'Total nota terbit',
                                                icon:
                                                    Icons.receipt_long_rounded,
                                                accent: AppColors.primaryBright,
                                                bgTint: isDark
                                                    ? AppColors
                                                        .primaryContainerDark
                                                        .withValues(alpha: 0.5)
                                                    : AppColors
                                                        .primaryContainerLight,
                                                isSelected: _activeListFilter ==
                                                    DashboardListFilter
                                                        .periodInvoices,
                                                onTap: () => _setListFilter(
                                                    DashboardListFilter
                                                        .periodInvoices),
                                                isDark: isDark,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // 2. Total Revenue for Period
                                            Expanded(
                                              child: _ExecutiveKpiCard(
                                                title: 'Total Omzet',
                                                value: formatRupiah(
                                                    periodTotalRevenue),
                                                subtitle:
                                                    'Nilai seluruh tagihan',
                                                icon: Icons
                                                    .account_balance_wallet_rounded,
                                                accent: AppColors.violet,
                                                bgTint: isDark
                                                    ? AppColors.violetDark
                                                        .withValues(alpha: 0.45)
                                                    : AppColors.violetLight,
                                                isSelected: false,
                                                onTap: () => _setListFilter(
                                                    DashboardListFilter.none),
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
                                                value: formatRupiah(
                                                    periodPaidRevenue),
                                                subtitle:
                                                    '$periodPaidCount nota lunas',
                                                icon: Icons.verified_rounded,
                                                accent: AppColors.teal,
                                                bgTint: isDark
                                                    ? AppColors.tealDark
                                                        .withValues(alpha: 0.45)
                                                    : AppColors.tealLight,
                                                isSelected: _activeListFilter ==
                                                    DashboardListFilter
                                                        .paidOnly,
                                                onTap: () => _setListFilter(
                                                    DashboardListFilter
                                                        .paidOnly),
                                                isDark: isDark,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // 4. Unpaid Due (Outstanding)
                                            Expanded(
                                              child: _ExecutiveKpiCard(
                                                title: 'Belum Lunas',
                                                value: formatRupiah(
                                                    periodUnpaidRevenue),
                                                subtitle:
                                                    '$periodUnpaidCount nota belum lunas',
                                                icon: Icons
                                                    .pending_actions_rounded,
                                                accent: AppColors.warmOrange,
                                                bgTint: isDark
                                                    ? AppColors.warmOrangeDark
                                                        .withValues(alpha: 0.45)
                                                    : AppColors.warmOrangeLight,
                                                isSelected: _activeListFilter ==
                                                    DashboardListFilter
                                                        .unpaidOnly,
                                                onTap: () => _setListFilter(
                                                    DashboardListFilter
                                                        .unpaidOnly),
                                                isDark: isDark,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Progress Bar: Tingkat Pelunasan Tagihan
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors
                                                    .darkSurfaceElevated
                                                    .withValues(alpha: 0.7)
                                                : AppColors
                                                    .lightSurfaceElevated,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Tingkat Pelunasan Tagihan',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isDark
                                                          ? AppColors
                                                              .darkTextSecondary
                                                          : AppColors
                                                              .lightTextSecondary,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${(paymentCollectionRate * 100).toStringAsFixed(0)}% Lunas',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: paymentCollectionRate >=
                                                              0.8
                                                          ? AppColors.teal
                                                          : AppColors
                                                              .warmOrange,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: paymentCollectionRate,
                                                  minHeight: 5,
                                                  backgroundColor: isDark
                                                      ? AppColors.darkBorder
                                                      : AppColors.lightBorder,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    paymentCollectionRate >= 0.8
                                                        ? AppColors.teal
                                                        : AppColors.warmOrange,
                                                  ),
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
                                // SECTION B: SHORTCUT KE ANTREAN CUCIAN
                                // ==========================================
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      onTap: () =>
                                          widget.onNavigateTab?.call(1),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.all(13),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isDark
                                                ? [
                                                    AppColors.cyanDark
                                                        .withValues(
                                                            alpha: 0.35),
                                                    AppColors.primaryDark
                                                        .withValues(
                                                            alpha: 0.35),
                                                  ]
                                                : [
                                                    AppColors.cyanLight,
                                                    AppColors
                                                        .primaryContainerLight,
                                                  ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: AppColors.cyan
                                                .withValues(alpha: 0.3),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: AppColors.cyan,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons
                                                    .local_laundry_service_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Text(
                                                        'Antrean Operasional',
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 1.5,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors.cyan,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: Text(
                                                          '$activeQueueCount AKTIF',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    'Pantau tahapan cuci, setrika, siap diambil & antar',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark
                                                          ? AppColors
                                                              .darkTextSecondary
                                                          : AppColors
                                                              .lightTextSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppColors.cyan,
                                              size: 22,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Quick Cashier Action Pills
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _QuickActionPill(
                                          icon: Icons.add_circle_outline_rounded,
                                          label: 'Buat Nota',
                                          color: AppColors.primaryBright,
                                          isDark: isDark,
                                          onTap: _newOrder,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _QuickActionPill(
                                          icon: Icons.people_outline_rounded,
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
                                              widget.onNavigateTab?.call(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              // ==========================================
                              // SECTION C: DAFTAR TRANSAKSI & INVOICE
                              // ==========================================
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
                                          height: 15,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryBright,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          activeFilterLabel,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_activeListFilter !=
                                        DashboardListFilter.none)
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                        ),
                                        icon: const Icon(Icons.close_rounded,
                                            size: 15),
                                        label: const Text(
                                          'Reset Filter',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        onPressed: () => _setListFilter(
                                            DashboardListFilter.none),
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
                      if (displayedOrders.isEmpty)
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
                                      Icons.receipt_long_outlined,
                                      size: 32,
                                      color: AppColors.neutral,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Tidak ditemukan nota "$_searchQuery"'
                                        : 'Belum ada transaksi di periode ini',
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Buat nota transaksi baru dengan tombol di bawah.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.neutral,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    onPressed: _newOrder,
                                    icon: const Icon(Icons.add_rounded,
                                        size: 18),
                                    label: const Text('Buat Nota Baru'),
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
                                final order = displayedOrders[index];
                                return OrderTile(
                                  order: order,
                                  onTap: () => _openDetail(order),
                                );
                              },
                              childCount: displayedOrders.length,
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

/// Executive KPI Card for Invoices & Financials
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
                : (isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.lightSurfaceElevated),
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
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      : (isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? AppColors.primaryBright : AppColors.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryBright.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
            ),
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

