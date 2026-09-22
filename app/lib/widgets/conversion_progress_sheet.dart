import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/core.dart';

/// La feuille de progression pendant une conversion.
class ConversionProgressSheet extends StatelessWidget {
  final double progress;
  final String conversionLabel;

  const ConversionProgressSheet({
    super.key,
    required this.progress,
    required this.conversionLabel,
  });

  String get _statusText {
    if (progress < 0.3) return 'Lecture du fichier';
    if (progress < 0.9) return 'Conversion en cours';
    return 'Finalisation';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final percent = (progress.clamp(0.0, 1.0) * 100).round();

    return Semantics(
      liveRegion: true,
      label: '$_statusText, $percent pour cent',
      child: Container(
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
              const _SheetHandle(),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.sync_rounded,
                    color: colors.onPrimaryContainer, size: 32),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .rotate(duration: 1800.ms, curve: Curves.easeInOut),
              const SizedBox(height: AppSpacing.xl),
              Text(conversionLabel, style: context.texts.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(_statusText, style: context.texts.bodyMedium),
              const SizedBox(height: AppSpacing.xxl),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('$percent %', style: context.texts.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: context.palette.border,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
