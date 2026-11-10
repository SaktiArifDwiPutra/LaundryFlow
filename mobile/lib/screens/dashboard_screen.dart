import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
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
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nota #${created.number} berhasil diterbitkan')),
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

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final now = DateTime.now();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        backgroundColor: AppColors.primaryBright,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: const Text(
          'Transaksi Kasir',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
        elevation: 5,
      ),
      body: Column(
        children: [
          // 1. Executive POS Header (Clean: Just greeting + calendar, NO extra branding, NO refresh button)
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
                // Top Brand & Cashier Greeting
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
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greetingText(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: Color(0xFFBFDBFE),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                formatDateIndonesian(now),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFDBEAFE),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Search Bar for Invoices
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
                      hintText: 'Cari no. nota (#LDR), nama, atau telepon...',
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

          // 2. Main Executive Dashboard Content
          Expanded(
            child: FutureBuilder<_DashboardData>(
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
                            'Gagal memuat data dashboard: ${snapshot.error}',
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
                final allOrders = data.allOrders;

                // 1. Calculate Period Filtered Orders
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
                    : (periodPaidRevenue /
                            (periodTotalRevenue == 0 ? 1 : periodTotalRevenue))
                        .clamp(0.0, 1.0);

                // Average Order Value (AOV)
                final averageOrderValue = periodOrderCount == 0
                    ? 0
                    : (periodTotalRevenue / periodOrderCount).round();

                // 2. Calculate Service & Speed Breakdown
                final serviceVolumeMap = <String, double>{};
                int expressCount = 0;
                int regularCount = 0;
                int deliveryCount = 0;
                int pickupCount = 0;

                for (final o in periodOrders) {
                  if (o.isExpress) {
                    expressCount++;
                  } else {
                    regularCount++;
                  }

                  if (o.fulfillment == Fulfillment.delivery) {
                    deliveryCount++;
                  } else {
                    pickupCount++;
                  }

                  for (final line in o.lines) {
                    final current = serviceVolumeMap[line.serviceName] ?? 0.0;
                    serviceVolumeMap[line.serviceName] = current + line.qty;
                  }
                }

                // Top services sorted by quantity
                final sortedServices = serviceVolumeMap.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final topServices = sortedServices.take(3).toList();
                final totalVolumeAll = serviceVolumeMap.values
                    .fold<double>(0.0, (sum, val) => sum + val);

                // 3. Transaction History (Completed and Paid orders only)
                final baseOrders = _searchQuery.isNotEmpty ? allOrders : periodOrders;
                final historyOrders = baseOrders
                    .where((o) => o.status == OrderStatus.completed && o.isPaid)
                    .toList();

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
                              // SECTION A: FINANCIAL & KPI DASHBOARD
                              // ==========================================
                              if (_searchQuery.isEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
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
                                        // Header Row: Title & Subtitle (Clean horizontal full-width)
                                        Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBright
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.analytics_rounded,
                                                color: AppColors.primaryBright,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Ringkasan Keuangan & Omzet',
                                                    style: TextStyle(
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: -0.2,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    'Performa transaksi kasir dan arus kas toko',
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

                                        // Period Filter Bar (Equal width segmented control)
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
                                                      });
                                                    },
                                                    isDark: isDark,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 14),

                                        // 4 Bento Financial Cards
                                        Row(
                                          children: [
                                            // 1. Total Omzet
                                            Expanded(
                                              child: _ExecutiveKpiCard(
                                                title: 'Total Omzet',
                                                value: formatRupiah(
                                                    periodTotalRevenue),
                                                subtitle:
                                                    'Nilai seluruh penjualan',
                                                icon: Icons
                                                    .account_balance_wallet_rounded,
                                                accent: AppColors.primaryBright,
                                                bgTint: isDark
                                                    ? AppColors
                                                        .primaryContainerDark
                                                        .withValues(alpha: 0.5)
                                                    : AppColors
                                                        .primaryContainerLight,
                                                isDark: isDark,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // 2. Total Invoices
                                            Expanded(
                                              child: _ExecutiveKpiCard(
                                                title: 'Total Nota',
                                                value: '$periodOrderCount Nota',
                                                subtitle:
                                                    'Rata-rata: ${formatRupiah(averageOrderValue)}',
                                                icon:
                                                    Icons.receipt_long_rounded,
                                                accent: AppColors.violet,
                                                bgTint: isDark
                                                    ? AppColors.violetDark
                                                        .withValues(alpha: 0.45)
                                                    : AppColors.violetLight,
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
                                                title: 'Kas Masuk (Lunas)',
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
                                                isDark: isDark,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // 4. Unpaid Due (Receivables)
                                            Expanded(
                                              child: _ExecutiveKpiCard(
                                                title: 'Piutang (Belum)',
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
                                                isDark: isDark,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 14),

                                        // Cashflow Health Bar & Rate
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.darkSurfaceElevated
                                                    .withValues(alpha: 0.7)
                                                : AppColors
                                                    .lightSurfaceElevated,
                                            borderRadius:
                                                BorderRadius.circular(13),
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
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .payments_outlined,
                                                        size: 15,
                                                        color: AppColors.teal,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Tingkat Pelunasan Tagihan',
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isDark
                                                              ? AppColors
                                                                  .darkTextSecondary
                                                              : AppColors
                                                                  .lightTextSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '${(paymentCollectionRate * 100).toStringAsFixed(0)}% Lunas',
                                                    style: TextStyle(
                                                      fontSize: 12,
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
                                              const SizedBox(height: 8),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: LinearProgressIndicator(
                                                  value: paymentCollectionRate,
                                                  minHeight: 6,
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
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Kas Masuk: ${formatRupiah(periodPaidRevenue)}',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors.teal,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Piutang: ${formatRupiah(periodUnpaidRevenue)}',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.warmOrange,
                                                    ),
                                                  ),
                                                ],
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
                                // SECTION B: LAYANAN & PERFORMA BISNIS
                                // ==========================================
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurface
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(18),
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
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.teal
                                                        .withValues(
                                                            alpha: 0.14),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            9),
                                                  ),
                                                  child: const Icon(
                                                    Icons.pie_chart_rounded,
                                                    color: AppColors.teal,
                                                    size: 18,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                const Text(
                                                  'Distribusi Layanan & Mode',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (totalVolumeAll > 0)
                                              Text(
                                                'Total: ${totalVolumeAll.toStringAsFixed(1)} Qty',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.teal,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Mode Quick Badges: Reguler vs Kilat & Ambil vs Antar
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _StatMiniTile(
                                                icon: Icons.bolt_rounded,
                                                label: 'Layanan Kilat',
                                                value: '$expressCount Nota',
                                                subtext:
                                                    'Reguler: $regularCount Nota',
                                                color: AppColors.warmOrange,
                                                isDark: isDark,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _StatMiniTile(
                                                icon: Icons
                                                    .delivery_dining_rounded,
                                                label: 'Delivery Antar',
                                                value: '$deliveryCount Nota',
                                                subtext:
                                                    'Ambil Toko: $pickupCount',
                                                color: AppColors.cyan,
                                                isDark: isDark,
                                              ),
                                            ),
                                          ],
                                        ),

                                        if (topServices.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Layanan Terlaris Periode Ini:',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          for (final entry in topServices) ...[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(bottom: 6),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: AppColors
                                                          .primaryBright,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      entry.key,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isDark
                                                            ? AppColors
                                                                .darkTextPrimary
                                                            : AppColors
                                                                .lightTextPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${entry.value.toStringAsFixed(1)} Qty',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors
                                                          .primaryBright,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // ==========================================
                                // SECTION C: AKSI CEPAT KASIR
                                // ==========================================
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _DashboardActionTile(
                                          icon: Icons.add_shopping_cart_rounded,
                                          title: 'Buat Nota',
                                          subtitle: 'Transaksi Kasir',
                                          color: AppColors.primaryBright,
                                          isDark: isDark,
                                          onTap: _newOrder,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _DashboardActionTile(
                                          icon: Icons.people_rounded,
                                          title: 'Pelanggan',
                                          subtitle: 'Kelola Member',
                                          color: AppColors.teal,
                                          isDark: isDark,
                                          onTap: () =>
                                              widget.onNavigateTab?.call(3),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _DashboardActionTile(
                                          icon: Icons.receipt_long_rounded,
                                          title: 'Semua Nota',
                                          subtitle: 'Riwayat Faktur',
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

                              const SizedBox(height: 18),

                              // ==========================================
                              // SECTION D: RIWAYAT TRANSAKSI (SELESAI & LUNAS)
                              // ==========================================
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 15,
                                              decoration: BoxDecoration(
                                                color: AppColors.teal,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Riwayat Transaksi',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.teal
                                                .withValues(alpha: isDark ? 0.2 : 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: AppColors.teal
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            'SELESAI & LUNAS (${historyOrders.length})',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.teal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Transaksi yang telah tuntas dikerjakan dan pembayaran lunas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),

                      // History Orders List
                      if (historyOrders.isEmpty)
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
                                      Icons.verified_outlined,
                                      size: 32,
                                      color: AppColors.teal,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Tidak ditemukan riwayat selesai & lunas "$_searchQuery"'
                                        : 'Belum Ada Transaksi Selesai & Lunas',
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Pesanan yang berstatus selesai dan telah lunas di periode ${_selectedPeriod.label} akan tampil di sini.',
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
                                final order = historyOrders[index];
                                return OrderTile(
                                  order: order,
                                  onTap: () => _openDetail(order),
                                );
                              },
                              childCount: historyOrders.length,
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
    required this.isDark,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color bgTint;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
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
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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

/// Mini Stat Tile for Mode & Breakdown
class _StatMiniTile extends StatelessWidget {
  const _StatMiniTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtext;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashboard Quick Action Button Tile
class _DashboardActionTile extends StatelessWidget {
  const _DashboardActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.1,
            ),
            boxShadow: AppColors.cardShadow(isDark: isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.neutral,
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
