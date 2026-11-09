import 'package:flutter_test/flutter_test.dart';
import 'package:laundryflow/models/customer.dart';
import 'package:laundryflow/models/invoice.dart';
import 'package:laundryflow/models/order.dart';
import 'package:laundryflow/models/order_option.dart';
import 'package:laundryflow/models/order_status.dart';
import 'package:laundryflow/models/service.dart';
import 'package:laundryflow/models/service_speed.dart';

void main() {
  group('Customer Model Tests', () {
    test('Customer.fromJson parses standard payload', () {
      final json = {
        'id': 12,
        'name': 'Budi Santoso',
        'phone': '628123456789',
        'address': 'Jl. Mawar No. 10',
      };
      final c = Customer.fromJson(json);
      expect(c.id, 12);
      expect(c.name, 'Budi Santoso');
      expect(c.phone, '628123456789');
      expect(c.address, 'Jl. Mawar No. 10');
    });

    test('Customer.fromJson falls back to street and city if address is null', () {
      final json = {
        'id': 14,
        'name': 'Siti Rahma',
        'phone': '081299998888',
        'street': 'Jl. Melati 5',
        'city': 'Surabaya',
      };
      final c = Customer.fromJson(json);
      expect(c.address, 'Jl. Melati 5, Surabaya');
    });
  });

  group('Invoice Model Tests', () {
    test('Invoice.fromJson parses real API payload correctly', () {
      final json = {
        'invoice_number': 'INV/LDR/2026/00536',
        'order_id': 491,
        'order_number': 'LDR/2026/00536',
        'total_amount': 45000.0,
        'amount_paid': 50000.0,
        'amount_due': 0.0,
        'change_amount': 5000.0,
        'payment_status': 'paid',
        'payment_method': 'cash',
        'state': 'posted',
      };
      final inv = Invoice.fromJson(json);
      expect(inv.number, 'INV/LDR/2026/00536');
      expect(inv.orderId, 491);
      expect(inv.total, 45000);
      expect(inv.amountPaid, 50000);
      expect(inv.amountDue, 0);
      expect(inv.changeAmount, 5000);
      expect(inv.paymentState, 'paid');
      expect(inv.isPaid, isTrue);
      expect(inv.isPartial, isFalse);
      expect(inv.isUnpaid, isFalse);
      expect(inv.paymentLabel, 'Lunas');
      expect(inv.methodLabel, 'Tunai');
    });

    test('Invoice partial payment state', () {
      final json = {
        'id': 10,
        'number': 'INV-10',
        'total_amount': 50000,
        'amount_paid': 20000,
        'amount_due': 30000,
        'payment_status': 'partial',
      };
      final inv = Invoice.fromJson(json);
      expect(inv.isPaid, isFalse);
      expect(inv.isPartial, isTrue);
      expect(inv.isUnpaid, isFalse);
      expect(inv.paymentLabel, 'Dibayar sebagian');
    });
  });

  group('Order Model Tests', () {
    test('Order.fromJson parses Odoo order response', () {
      final json = {
        'id': 491,
        'name': 'LDR/2026/00536',
        'state': 'washing',
        'partner_id': 12,
        'partner_name': 'Budi Santoso',
        'phone': '628123456789',
        'total_amount': 35000,
        'payment_status': 'paid',
        'stages': ['received', 'washing', 'drying', 'ironing', 'ready', 'completed'],
        'lines': [
          {
            'id': 12,
            'product_name': 'Cuci Setrika',
            'quantity': 3.5,
            'price_unit': 10000.0,
            'subtotal': 35000.0,
            'uom': 'kg',
          }
        ],
      };
      final order = Order.fromJson(json);
      expect(order.id, 491);
      expect(order.number, 'LDR/2026/00536');
      expect(order.status, OrderStatus.washing);
      expect(order.customer.name, 'Budi Santoso');
      expect(order.total, 35000);
      expect(order.isPaid, isTrue);
      expect(order.lines.length, 1);
      expect(order.lines.first.qty, 3.5);
      expect(order.lines.first.unit, 'kg');
      expect(order.stages.length, 6);
    });

    test('Order.fromJson parses delivery fields from backend response', () {
      final json = {
        'id': 492,
        'name': 'LDR/2026/00537',
        'state': 'received',
        'partner_id': 12,
        'partner_name': 'Budi Santoso',
        'delivery_type': 'delivery',
        'delivery_address': 'Jl. Mawar No. 10',
        'delivery_fee': 10000,
        'total_amount': 45000,
        'stages': ['received', 'washing', 'drying', 'ironing', 'ready', 'out_for_delivery', 'completed'],
        'next_status': 'washing',
      };
      final order = Order.fromJson(json);
      expect(order.fulfillment, Fulfillment.delivery);
      expect(order.delivery, isNotNull);
      expect(order.delivery!.address, 'Jl. Mawar No. 10');
      expect(order.delivery!.fee, 10000);
      expect(order.stages.contains(OrderStatus.outForDelivery), isTrue);
    });
  });

  group('Service & Speed Model Tests', () {
    test('Service.fromJson handles weight pricing', () {
      final json = {
        'id': 1,
        'name': 'Cuci Kiloan',
        'pricing_type': 'weight',
        'list_price': 8000,
        'uom_name': 'kg',
      };
      final s = Service.fromJson(json);
      expect(s.id, 1);
      expect(s.pricingType, PricingType.weight);
      expect(s.unit, 'kg');
      expect(s.unitPrice, 8000);
    });

    test('ServiceSpeed.fromJson parses same_day correctly', () {
      final json = {
        'code': 'same_day',
        'name': 'Same Day Service',
        'fee': 10000,
        'available': true,
      };
      final speed = ServiceSpeed.fromJson(json);
      expect(speed.isSameDay, isTrue);
      expect(speed.available, isTrue);
      expect(speed.fee, 10000);
    });
  });
}

