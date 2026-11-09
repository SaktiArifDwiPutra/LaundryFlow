import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
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
  OrderSort _sort = OrderSort.createdAt;
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
      orderRepository.list(status: _status, q: _query, sort: _sort);

  void _reload() {
    setState(() {
      _future = _fetch();
    });
  }

  void _setStatus(OrderStatus? status) {
    _status = status;
    _reload();
  }

  void _setSort(OrderSort sort) {
    if (_sort == sort) return;
    _sort = sort;
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

  IconData _statusIcon(OrderStatus s) {
    return switch (s) {
      OrderStatus.received => Icons.inventory_2_rounded,
      OrderStatus.washing => Icons.local_laundry_service_rounded,
      OrderStatus.drying => Icons.wb_sunny_rounded,
      OrderStatus.ironing => Icons.iron_rounded,
      OrderStatus.ready => Icons.check_circle_rounded,
      OrderStatus.outForDelivery => Icons.delivery_dining_rounded,
      OrderStatus.completed => Icons.verified_rounded,
      OrderStatus.unknown => Icons.help_outline_rounded,
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
          'Nota Baru',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          // 1. Commercial Royal Blue & Indigo Header with Integrated Search & Sort
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
                      .withValues(alpha: isDark ? 0.45 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manajemen Pesanan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Seluruh riwayat & status nota transaksi',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFDBEAFE),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sort Toggle Pill
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SortPillButton(
                            label: 'Terbaru',
                            selected: _sort == OrderSort.createdAt,
                            onTap: () => _setSort(OrderSort.createdAt),
                          ),
                          _SortPillButton(
                            label: 'Tenggat',
                            selected: _sort == OrderSort.dueAt,
                            onTap: () => _setSort(OrderSort.dueAt),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        tooltip: 'Muat Ulang',
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        onPressed: _reload,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Input Field inside Header
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    onChanged: (v) {
                      setState(() {});
                      if (v.isEmpty) _clearSearch();
                    },
                    onSubmitted: _submitSearch,
                    decoration: InputDecoration(
                      hintText: 'Cari nama pelanggan, HP, atau no. nota...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.cancel_rounded, size: 18),
                              onPressed: _clearSearch,
                            ),
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
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. Horizontal Semantic Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _StatusFilterPill(
                  label: 'Semua Status',
                  icon: Icons.apps_rounded,
                  accent: AppColors.primaryBright,
                  selected: _status == null,
                  isDark: isDark,
                  onTap: () => _setStatus(null),
                ),
                for (final s in _filters) ...[
                  const SizedBox(width: 7),
                  _StatusFilterPill(
                    label: s.label,
                    icon: _statusIcon(s),
                    accent: AppColors.stageStyle(s, isDark: isDark).icon,
                    selected: _status == s,
                    isDark: isDark,
                    onTap: () => _setStatus(s),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 3. Order Stream / List with Live Financial Summary Strip
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
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppColors.danger,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Gagal memuat pesanan: ${snapshot.error}',
                            textAlign: TextAlign.center,
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

                final orders = snapshot.data!;
                if (orders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
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
                              color: isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _hasFilter
                                ? 'Tidak ada nota yang cocok dengan filter.'
                                : 'Belum ada data transaksi pesanan.',
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium,
                          ),
                          if (_hasFilter) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                _status = null;
                                _clearSearch();
                              },
                              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                              label: const Text('Reset Semua Filter'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                final totalNominal =
                    orders.fold<int>(0, (sum, o) => sum + o.total);
                final paidCount = orders.where((o) => o.isPaid).length;
                final unpaidCount = orders.length - paidCount;

                return Column(
                  children: [
                    // Live Summary Strip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${orders.length} Nota',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.primaryDark,
                                    ),
                                  ),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: AppColors.neutral,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 13,
                                        color: isDark
                                            ? const Color(0xFF34D399)
                                            : AppColors.success,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$paidCount Lunas',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFF6EE7B7)
                                              : AppColors.successText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (unpaidCount > 0)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.pending_actions_rounded,
                                          size: 13,
                                          color: isDark
                                              ? const Color(0xFFFDA4AF)
                                              : AppColors.danger,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$unpaidCount Belum',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? const Color(0xFFFDA4AF)
                                                : AppColors.dangerText,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatRupiah(totalNominal),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.primaryLight
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          _reload();
                          await _future;
                        },
                        child: ListView.builder(
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
          ),
        ],
      ),
    );
  }
}

class _SortPillButton extends StatelessWidget {
  const _SortPillButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.primaryDark : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _StatusFilterPill extends StatelessWidget {
  const _StatusFilterPill({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryActionGradient : null,
            color: selected
                ? null
                : (isDark ? AppColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13.5,
                color: selected ? Colors.white : accent,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
