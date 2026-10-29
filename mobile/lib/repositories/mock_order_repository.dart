import '../data/mock_data.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import 'order_repository.dart';

class MockOrderRepository implements OrderRepository {
  MockOrderRepository() : _db = buildMockOrderJson();

  final List<Map<String, dynamic>> _db;
  int _nextId = 100;

  static const _productionStages = {'received', 'washing', 'drying', 'ironing'};

  Future<void> _fakeDelay() =>
      Future.delayed(const Duration(milliseconds: 400));

  Map<String, dynamic> _decorate(Map<String, dynamic> raw) {
    final rawLines = (raw['lines'] as List).cast<Map<String, dynamic>>();

    var needWash = false;
    var needDry = false;
    var needIron = false;
    var subtotal = 0;
    final lines = <Map<String, dynamic>>[];
    for (var i = 0; i < rawLines.length; i++) {
      final l = rawLines[i];
      final qty = (l['qty'] as num).toDouble();
      final unitPrice = (l['unit_price'] as num).round();
      final lineTotal = (qty * unitPrice).round();
      subtotal += lineTotal;
      needWash = needWash || (l['needs_wash'] as bool? ?? true);
      needDry = needDry || (l['needs_dry'] as bool? ?? true);
      needIron = needIron || (l['needs_iron'] as bool? ?? true);
      lines.add({
        'id': i + 1,
        'product_id': l['product_id'],
        'product_name': l['product_name'],
        'qty': qty,
        'uom': l['uom'],
        'unit_price': unitPrice,
        'subtotal': lineTotal,
      });
    }

    final isDelivery = raw['fulfillment'] == 'delivery';
    final stages = <String>[
      'received',
      if (needWash) 'washing',
      if (needDry) 'drying',
      if (needIron) 'ironing',
      'ready',
      if (isDelivery) 'out_for_delivery',
      'completed',
    ];

    final status = raw['status'] as String;
    final index = stages.indexOf(status);
    final next =
        (index >= 0 && index < stages.length - 1) ? stages[index + 1] : null;

    final isExpress = raw['priority'] == 'express';
    final expressFee = isExpress ? ((subtotal * 0.2) / 500).round() * 500 : 0;
    final deliveryRaw = raw['delivery'] as Map<String, dynamic>?;
    final deliveryFee =
        isDelivery ? ((deliveryRaw?['fee'] as num?)?.round() ?? 0) : 0;

    final due = DateTime.parse(raw['due_at'] as String);
    final overdue = _productionStages.contains(status) &&
        DateTime.now().toUtc().isAfter(due);

    return {
      ...raw,
      'lines': lines,
      'stages': stages,
      'next_status': next,
      'is_overdue': overdue,
      'express_fee': expressFee,
      'total': subtotal + expressFee + deliveryFee,
      'currency': 'IDR',
      'delivery': isDelivery
          ? {
              'address': deliveryRaw?['address'] ?? '',
              'fee': deliveryFee,
              'courier': null,
            }
          : null,
    };
  }

  int _indexOf(int id) {
    final index = _db.indexWhere((o) => o['id'] == id);
    if (index == -1) throw StateError('Pesanan $id tidak ditemukan');
    return index;
  }

  @override
  Future<List<Order>> list({
    OrderStatus? status,
    String q = '',
    bool activeOnly = false,
    OrderSort sort = OrderSort.createdAt,
  }) async {
    await _fakeDelay();
    final query = q.trim().toLowerCase();

    final result = _db.map(_decorate).where((o) {
      if (status != null && o['status'] != status.code) return false;
      if (activeOnly && o['status'] == 'completed') return false;
      if (query.isEmpty) return true;
      final c = o['customer'] as Map<String, dynamic>;
      return (c['name'] as String).toLowerCase().contains(query) ||
          (c['phone'] as String).contains(query) ||
          (o['number'] as String).toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) {
      if (sort == OrderSort.dueAt) {
        return DateTime.parse(a['due_at'] as String)
            .compareTo(DateTime.parse(b['due_at'] as String));
      }
      return DateTime.parse(b['created_at'] as String)
          .compareTo(DateTime.parse(a['created_at'] as String));
    });

    return result.map(Order.fromJson).toList();
  }

  @override
  Future<Order> get(int id) async {
    await _fakeDelay();
    return Order.fromJson(_decorate(_db[_indexOf(id)]));
  }

  @override
  Future<Order> create({
    required Customer customer,
    required List<OrderLineInput> lines,
    String notes = '',
    OrderPriority priority = OrderPriority.regular,
    Fulfillment fulfillment = Fulfillment.pickup,
    String deliveryAddress = '',
    int deliveryFee = 0,
  }) async {
    await _fakeDelay();
    if (lines.isEmpty) {
      throw const OrderValidationException('Pilih minimal satu layanan.');
    }
    if (fulfillment == Fulfillment.delivery &&
        deliveryAddress.trim().isEmpty) {
      throw const OrderValidationException('Alamat pengantaran wajib diisi.');
    }

    final now = DateTime.now().toUtc();
    final id = _nextId++;
    final raw = <String, dynamic>{
      'id': id,
      'number': 'LF-${now.year}-${id.toString().padLeft(4, '0')}',
      'status': 'received',
      'priority': priority.code,
      'fulfillment': fulfillment.code,
      'delivery': fulfillment == Fulfillment.delivery
          ? {'address': deliveryAddress.trim(), 'fee': deliveryFee}
          : null,
      'customer': {
        'id': customer.id,
        'name': customer.name,
        'phone': customer.phone,
      },
      'lines': [for (final l in lines) lineSnapshot(l.service, l.qty)],
      'notes': notes,
      // Tenggat contoh: express 24 jam, reguler 48 jam.
      'due_at': now
          .add(Duration(hours: priority == OrderPriority.express ? 24 : 48))
          .toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    _db.insert(0, raw);
    return Order.fromJson(_decorate(raw));
  }

  @override
  Future<Order> advanceStatus(int id, OrderStatus to) async {
    await _fakeDelay();
    final index = _indexOf(id);
    final decorated = _decorate(_db[index]);
    if (decorated['next_status'] != to.code) {
      throw const InvalidTransitionException('Status tidak boleh dilompati.');
    }
    _db[index] = {
      ..._db[index],
      'status': to.code,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    return Order.fromJson(_decorate(_db[index]));
  }

  @override
  Future<Order> setFulfillment(
    int id,
    Fulfillment fulfillment, {
    String deliveryAddress = '',
    int deliveryFee = 0,
  }) async {
    await _fakeDelay();
    final index = _indexOf(id);
    final status = _db[index]['status'];
    if (status == 'out_for_delivery' || status == 'completed') {
      throw const InvalidTransitionException(
        'Pilihan ambil/antar tidak bisa diubah lagi.',
      );
    }
    if (fulfillment == Fulfillment.delivery &&
        deliveryAddress.trim().isEmpty) {
      throw const OrderValidationException('Alamat pengantaran wajib diisi.');
    }
    _db[index] = {
      ..._db[index],
      'fulfillment': fulfillment.code,
      'delivery': fulfillment == Fulfillment.delivery
          ? {'address': deliveryAddress.trim(), 'fee': deliveryFee}
          : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    return Order.fromJson(_decorate(_db[index]));
  }

  @override
  Future<OrderSummary> summary() async {
    await _fakeDelay();
    final byStatus = <OrderStatus, int>{};
    var overdue = 0;
    var express = 0;
    for (final o in _db.map(_decorate)) {
      final s = OrderStatus.fromCode(o['status'] as String?);
      if (s == OrderStatus.completed || s == OrderStatus.unknown) continue;
      byStatus[s] = (byStatus[s] ?? 0) + 1;
      if (o['is_overdue'] == true) overdue++;
      if (o['priority'] == 'express') express++;
    }
    return OrderSummary(byStatus: byStatus, overdue: overdue, express: express);
  }
}