import 'package:flutter/material.dart';
import '../../core/core.dart';

class PremiumBanner extends StatelessWidget {
  final int remainingConversions;
  final VoidCallback onUpgrade;

  const PremiumBanner({
    super.key,
    required this.remainingConversions,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = remainingConversions <= 1;

    return GestureDetector(
      onTap: onUpgrade,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isLow
              ? const LinearGradient(
                  colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (isLow ? AppColors.premium : AppColors.primary).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isLow ? Icons.warning_amber_rounded : Icons.bolt_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLow
                        ? 'Plus que $remainingConversions conversion${remainingConversions > 1 ? 's' : ''} aujourd\'hui'
                        : '$remainingConversions conversions restantes aujourd\'hui',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Passe à Premium pour des conversions illimitées',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
