import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/order_option.dart';

class FulfillmentFields extends StatelessWidget {
  const FulfillmentFields({
    super.key,
    required this.value,
    required this.onChanged,
    required this.address,
    required this.fee,
    this.onFieldChanged,
  });

  final Fulfillment value;
  final ValueChanged<Fulfillment> onChanged;
  final TextEditingController address;
  final TextEditingController fee;
  final VoidCallback? onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final f in Fulfillment.values)
              ChoiceChip(
                label: Text(f.label),
                selected: value == f,
                onSelected: (_) => onChanged(f),
              ),
          ],
        ),
        if (value == Fulfillment.delivery) ...[
          const SizedBox(height: 16),
          TextField(
            controller: address,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alamat pengantaran',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onFieldChanged?.call(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: fee,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Ongkos kirim (Rp, opsional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onFieldChanged?.call(),
          ),
        ],
      ],
    );
  }
}