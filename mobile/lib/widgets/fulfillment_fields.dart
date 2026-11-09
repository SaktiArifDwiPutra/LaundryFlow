import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/order_option.dart';
import '../theme/app_colors.dart';

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

  void _setQuickFee(int amount) {
    fee.text = amount == 0 ? '0' : '$amount';
    onFieldChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDelivery = value == Fulfillment.delivery;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDelivery
              ? AppColors.cyanBright.withValues(alpha: isDark ? 0.65 : 0.45)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isDelivery ? 1.8 : 1.2,
        ),
        boxShadow: AppColors.cardShadow(isDark: isDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Side-by-side Segmented Cards for Pickup vs Delivery
          Row(
            children: [
              Expanded(
                child: _FulfillmentCardOption(
                  title: 'Ambil di Toko',
                  subtitle: 'Pelanggan datang',
                  icon: Icons.storefront_rounded,
                  selected: value == Fulfillment.pickup,
                  accent: AppColors.teal,
                  isDark: isDark,
                  onTap: () => onChanged(Fulfillment.pickup),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FulfillmentCardOption(
                  title: 'Antar ke Alamat',
                  subtitle: 'Kurir / Delivery',
                  icon: Icons.delivery_dining_rounded,
                  selected: value == Fulfillment.delivery,
                  accent: AppColors.cyan,
                  isDark: isDark,
                  onTap: () => onChanged(Fulfillment.delivery),
                ),
              ),
            ],
          ),

          if (isDelivery) ...[
            const SizedBox(height: 14),
            TextField(
              controller: address,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alamat Lengkap Pengantaran',
                hintText: 'Nama jalan, nomor rumah, RT/RW, atau patokan...',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              onChanged: (_) => onFieldChanged?.call(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fee,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Ongkos Kirim (Rp)',
                prefixText: 'Rp ',
                prefixIcon: Icon(Icons.two_wheeler_rounded),
              ),
              onChanged: (_) => onFieldChanged?.call(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _QuickFeeChip(
                  label: 'Gratis (Rp 0)',
                  onTap: () => _setQuickFee(0),
                ),
                _QuickFeeChip(
                  label: 'Rp 10.000',
                  onTap: () => _setQuickFee(10000),
                ),
                _QuickFeeChip(
                  label: 'Rp 15.000',
                  onTap: () => _setQuickFee(15000),
                ),
                _QuickFeeChip(
                  label: 'Rp 20.000',
                  onTap: () => _setQuickFee(20000),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FulfillmentCardOption extends StatelessWidget {
  const _FulfillmentCardOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color accent;
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.25 : 0.10)
                : (isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.lightSurfaceElevated),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accent
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? accent
                      : accent.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : accent,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
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
      ),
    );
  }
}

class _QuickFeeChip extends StatelessWidget {
  const _QuickFeeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.cyanGlow : AppColors.cyan,
        ),
      ),
      backgroundColor: isDark
          ? AppColors.cyanDark.withValues(alpha: 0.4)
          : AppColors.cyanLight,
      side: BorderSide(
        color: AppColors.cyan.withValues(alpha: 0.35),
      ),
      onPressed: onTap,
    );
  }
}
