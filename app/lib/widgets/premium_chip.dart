import 'package:flutter/material.dart';
import '../core/core.dart';

/// La marque d'un compte Premium.
class PremiumChip extends StatelessWidget {
  const PremiumChip({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      label: 'Compte Premium',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: palette.premiumSurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: palette.premium.withAlpha(89)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: palette.premium),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Premium',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.premium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
