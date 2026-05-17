import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../core/core.dart';

class ConversionProgressSheet extends StatelessWidget {
  final double progress;
  final String conversionLabel;

  const ConversionProgressSheet({
    super.key,
    required this.progress,
    required this.conversionLabel,
  });

  String get _statusText {
    if (progress < 0.3) return 'Analyse du fichier...';
    if (progress < 0.6) return 'Conversion en cours...';
    if (progress < 0.9) return 'Finalisation...';
    return 'Presque terminé !';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Animation icône
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sync_rounded,
              color: AppColors.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            conversionLabel,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),

          Text(
            _statusText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),

          LinearPercentIndicator(
            lineHeight: 10,
            percent: progress.clamp(0.0, 1.0),
            progressColor: AppColors.primary,
            backgroundColor: AppColors.surfaceVariant,
            barRadius: const Radius.circular(10),
            padding: EdgeInsets.zero,
            animation: true,
            animateFromLastPercent: true,
          ),
          const SizedBox(height: 12),

          Text(
            '${(progress * 100).toInt()}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
