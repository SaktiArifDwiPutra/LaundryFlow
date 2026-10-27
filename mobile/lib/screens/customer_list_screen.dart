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
    setState(() {
      _future = customerRepository.list(q: _search.text.trim());
    });
  }

  Future<void> _addCustomer() async {
    final created = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
    );
    if (created == null || !mounted) return;
    _search.clear();
    setState(() {
      _future = customerRepository.list();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${created.name} ditambahkan')),
    );
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
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Cari nama atau nomor HP',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Gagal memuat pelanggan: ${snapshot.error}'),
                  );
                }
                final customers = snapshot.data!;
                if (customers.isEmpty) {
                  return const Center(child: Text('Pelanggan tidak ditemukan.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final c = customers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(c.name.isEmpty ? '?' : c.name[0]),
                      ),
                      title: Text(c.name),
                      subtitle: Text(c.phone),
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