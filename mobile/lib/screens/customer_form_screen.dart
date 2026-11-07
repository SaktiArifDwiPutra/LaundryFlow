import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import '../repositories/repositories.dart';
import '../theme/app_colors.dart';
import '../utils/phone.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      final Customer created = await customerRepository.create(
        name: _name.text.trim(),
        phone: normalizePhone(_phone.text)!,
        address: _address.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on DuplicateCustomerException catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Pelanggan Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap Pelanggan',
                hintText: 'Contoh: Budi Santoso',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama lengkap wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp / HP',
                hintText: 'Contoh: 08123456789',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => normalizePhone(v ?? '') == null
                  ? 'Format nomor HP tidak valid (min 9 digit)'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alamat Pengantaran (Opsional)',
                hintText: 'Jalan, nomor rumah, kelurahan / patokan',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serverError!,
                        style: const TextStyle(color: AppColors.dangerText, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Menyimpan ke Odoo...' : 'Simpan Pelanggan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
