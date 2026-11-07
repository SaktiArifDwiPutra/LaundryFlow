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
    _search.text = created.name;
    _runSearch();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pelanggan ${created.name} berhasil ditambahkan')),
    );
  }

  Future<void> _openCustomerActions(Customer c) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        if (c.phone.isNotEmpty)
                          Text(c.phone,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.neutral)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart_outlined,
                  color: AppColors.primary),
              title: const Text('Buat Pesanan Baru'),
              subtitle:
                  const Text('Langsung buat pesanan untuk pelanggan ini'),
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
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Hapus Pelanggan',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteCustomer(c);
              },
            ),
            const SizedBox(height: 8),
          ],
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? 'Pilih Pelanggan' : 'Data Pelanggan'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add),
        label: const Text('Pelanggan Baru'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Cari nama atau nomor HP...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clearSearch,
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Customers List
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
                          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                          const SizedBox(height: 12),
                          Text('Gagal memuat pelanggan: ${snapshot.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 56,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          const SizedBox(height: 12),
                          Text('Pencarian Pelanggan', style: textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Ketik nama atau nomor HP untuk mencari pelanggan.',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 56,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        const SizedBox(height: 12),
                        Text('Pelanggan tidak ditemukan.', style: textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Tambah Pelanggan Baru'),
                          onPressed: _addCustomer,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _runSearch();
                    await _future;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 88),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final c = customers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: widget.selectMode
                              ? () => Navigator.of(context).pop(c)
                              : () => _openCustomerActions(c),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
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
                                        style: textTheme.titleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 14, color: AppColors.neutral),
                                          const SizedBox(width: 4),
                                          Text(
                                            c.phone.isEmpty ? 'Tanpa nomor HP' : c.phone,
                                            style: textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      if (c.address.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.neutral),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                c.address,
                                                style: textTheme.bodySmall,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (widget.selectMode)
                                  const Icon(Icons.chevron_right, color: AppColors.primary)
                                else
                                  const Icon(Icons.more_vert, color: AppColors.neutral, size: 20),
                              ],
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
