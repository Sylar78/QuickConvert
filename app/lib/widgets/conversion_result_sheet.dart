import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/core.dart';
import '../models/models.dart';
import 'format_badge.dart';

/// La feuille de résultat, une fois la conversion réussie.
class ConversionResultSheet extends StatelessWidget {
  final List<String> outputNames;
  final ConversionRoute route;
  final bool canShare;
  final VoidCallback onShare;
  final VoidCallback onOpen;
  final VoidCallback onConvertAgain;

  const ConversionResultSheet({
    super.key,
    required this.outputNames,
    required this.route,
    required this.canShare,
    required this.onShare,
    required this.onOpen,
    required this.onConvertAgain,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final count = outputNames.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.xxl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: palette.success.withAlpha(36),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: palette.success, size: 34),
            ).animate().scale(
                  duration: AppDuration.slow,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1, 1),
                ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              count > 1 ? '$count fichiers prêts' : 'Fichier prêt',
              style: context.texts.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              outputNames.isEmpty ? route.label : outputNames.first,
              style: context.texts.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xl),

            FormatTransition(
              from: route.from,
              to: route.to,
              size: FormatBadgeSize.small,
            ),
            const SizedBox(height: AppSpacing.xxl),

            Row(
              children: [
                if (canShare) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.ios_share_rounded, size: 19),
                      label: const Text('Partager'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onOpen,
                    icon: Icon(
                      canShare ? Icons.open_in_new_rounded : Icons.download_rounded,
                      size: 19,
                    ),
                    label: Text(canShare ? 'Ouvrir' : 'Télécharger'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onConvertAgain,
              child: const Text('Convertir autre chose'),
            ),
          ],
        ),
      ),
    );
  }
}
