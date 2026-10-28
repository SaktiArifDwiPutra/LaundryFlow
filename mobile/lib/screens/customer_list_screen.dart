import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../repositories/repositories.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key, this.selectMode = false});

  final bool selectMode;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _search = TextEditingController();
  Future<List<Customer>>? _future;
  bool _deleting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _runSearch() {
    final q = _search.text.trim();
    setState(() {
      _future = q.isEmpty ? null : customerRepository.list(q: q);
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
      SnackBar(content: Text('${created.name} ditambahkan')),
    );
  }

  Future<void> _deleteCustomer(Customer c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pelanggan?'),
        content: Text(
          '${c.name} akan dihapus dari server. '
          'Kalau pelanggan ini sudah punya transaksi, datanya mungkin '
          'hanya diarsipkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await customerRepository.delete(c.id);
      if (!mounted) return;
      _runSearch();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${c.name} dihapus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? 'Pilih Pelanggan' : 'Pelanggan'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomer,
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Cari nama atau nomor HP',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _future == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Ketik nama atau nomor HP pelanggan, lalu tekan tombol cari di keyboard.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : FutureBuilder<List<Customer>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Gagal memuat pelanggan: ${snapshot.error}',
                          ),
                        );
                      }
                      final customers = snapshot.data!;
                      if (customers.isEmpty) {
                        return const Center(
                          child: Text('Pelanggan tidak ditemukan.'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final c = customers[index];
                          final subtitle = [
                            c.phone.isEmpty ? 'Tanpa nomor HP' : c.phone,
                            if (c.address.isNotEmpty) c.address,
                          ].join(' • ');
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(c.name.isEmpty ? '?' : c.name[0]),
                            ),
                            title: Text(c.name),
                            subtitle: Text(subtitle),
                            trailing: widget.selectMode
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Hapus',
                                    onPressed: _deleting
                                        ? null
                                        : () => _deleteCustomer(c),
                                  ),
                            onTap: widget.selectMode
                                ? () => Navigator.of(context).pop(c)
                                : null,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}