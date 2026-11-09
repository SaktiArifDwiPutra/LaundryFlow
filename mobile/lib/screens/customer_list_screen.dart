import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../repositories/repositories.dart';
import '../theme/app_colors.dart';
import 'customer_form_screen.dart';
import 'new_order_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key, this.selectMode = false});

  final bool selectMode;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _search = TextEditingController();
  late Future<List<Customer>> _future;

  @override
  void initState() {
    super.initState();
    _future = customerRepository.list();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _runSearch() {
    final q = _search.text.trim();
    setState(() {
      _future = customerRepository.list(q: q);
    });
  }

  void _clearSearch() {
    _search.clear();
    _runSearch();
  }

  Future<void> _addCustomer() async {
    final created = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
    );
    if (created == null || !mounted) return;
    if (widget.selectMode) {
      Navigator.of(context).pop(created);
      return;
    }
    _search.text = created.name;
    _runSearch();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pelanggan ${created.name} berhasil ditambahkan')),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  Future<void> _openCustomerActions(Customer c) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarStyle = AppColors.avatarStyle(c.name, isDark: isDark);

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: avatarStyle.bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          _initials(c.name),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: avatarStyle.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (c.phone.isNotEmpty)
                            Text(
                              c.phone,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.neutral,
                              ),
                            ),
                          if (c.address.isNotEmpty)
                            Text(
                              c.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.neutral,
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
              const SizedBox(height: 14),
              const Divider(),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBright.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: AppColors.primaryBright,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Buat Nota Pesanan Baru',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Langsung buka kasir dengan pelanggan ini',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NewOrderScreen(initialCustomer: c),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Hapus Data Pelanggan',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteCustomer(c);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCustomer(Customer c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pelanggan?'),
        content: Text(
          'Pelanggan "${c.name}" akan dihapus dari data server.\n'
          'Jika sudah memiliki transaksi, data mungkin diarsipkan oleh Odoo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await customerRepository.delete(c.id);
      if (!mounted) return;
      _runSearch();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${c.name} berhasil dihapus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
        label: const Text(
          'Pelanggan Baru',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          // 1. Commercial Hero Header with Integrated Customer Search
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.selectMode ? topPadding + 6 : topPadding + 10,
              16,
              14,
            ),
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
                    if (widget.selectMode) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                    ] else ...[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.people_alt_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.selectMode
                                ? 'Pilih Pelanggan Transaksi'
                                : 'Database Pelanggan',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            widget.selectMode
                                ? 'Ketuk kartu pelanggan untuk memilih ke nota'
                                : 'Direktori kontak WhatsApp & alamat pengiriman',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFDBEAFE),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        tooltip: 'Tambah Pelanggan',
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        onPressed: _addCustomer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar inside Header
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
                    onChanged: (_) => _runSearch(),
                    onSubmitted: (_) => _runSearch(),
                    decoration: InputDecoration(
                      hintText: 'Cari nama pelanggan atau nomor WhatsApp...',
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

          // 2. Customers List
          Expanded(
            child: FutureBuilder<List<Customer>>(
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
                            'Gagal memuat pelanggan: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Coba Lagi'),
                            onPressed: _runSearch,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final customers = snapshot.data!;
                if (customers.isEmpty) {
                  if (_search.text.trim().isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                                Icons.person_search_rounded,
                                size: 34,
                                color: isDark
                                    ? AppColors.primaryLight
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Cari Pelanggan Toko',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ketik minimal 2 huruf nama atau nomor HP di kolom pencarian atas.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _addCustomer,
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                              label: const Text('Daftarkan Pelanggan Baru'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.tealLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_off_outlined,
                              size: 30,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Pelanggan "${_search.text.trim()}" belum terdaftar.',
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.teal,
                            ),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text('Tambah Pelanggan Baru'),
                            onPressed: _addCustomer,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _runSearch();
                    await _future;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 88),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final c = customers[index];
                      final avatarStyle =
                          AppColors.avatarStyle(c.name, isDark: isDark);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5.5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 1.2,
                          ),
                          boxShadow: AppColors.cardShadow(isDark: isDark),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: widget.selectMode
                                ? () => Navigator.of(context).pop(c)
                                : () => _openCustomerActions(c),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: avatarStyle.bg,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _initials(c.name),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: avatarStyle.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: textTheme.titleMedium?.copyWith(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors.tealDark
                                                        .withValues(alpha: 0.45)
                                                    : AppColors.tealLight,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.phone_iphone_rounded,
                                                    size: 11.5,
                                                    color: isDark
                                                        ? AppColors.tealGlow
                                                        : AppColors.teal,
                                                  ),
                                                  const SizedBox(width: 3.5),
                                                  Text(
                                                    c.phone.isEmpty
                                                        ? 'Tanpa HP'
                                                        : c.phone,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isDark
                                                          ? AppColors.tealGlow
                                                          : AppColors.teal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (c.address.isNotEmpty) ...[
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                size: 13.5,
                                                color: AppColors.neutral,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  c.address,
                                                  style: textTheme.bodySmall,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (widget.selectMode)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.primaryContainerDark
                                            : AppColors.primaryContainerLight,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Text(
                                        'Pilih',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.primary,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkSurfaceElevated
                                            : AppColors.lightSurfaceElevated,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: const Icon(
                                        Icons.more_horiz_rounded,
                                        color: AppColors.neutral,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
