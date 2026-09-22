import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import '../core/core.dart';
import '../models/models.dart';

/// La zone de dépôt : le premier geste de l'app.
///
/// C'est le changement de fond de la refonte. Avant, l'accueil demandait de
/// choisir un couple de formats parmi sept tuiles avant même d'avoir montré
/// son fichier ; ici on part du fichier, et l'app en déduit ce qu'elle peut
/// en faire.
class DropZone extends StatelessWidget {
  final VoidCallback onTap;

  const DropZone({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;

    return Semantics(
      button: true,
      label: 'Choisir un fichier à convertir',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: DottedBorder(
            color: colors.primary.withAlpha(115),
            strokeWidth: 1.5,
            dashPattern: const [7, 5],
            borderType: BorderType.RRect,
            radius: const Radius.circular(AppRadius.lg),
            padding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xxxl, horizontal: AppSpacing.xl),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(13),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 30,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Choisir un fichier',
                    style: context.texts.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'On te proposera les formats de sortie possibles',
                    style: context.texts.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final format in ConversionCatalog.inputFormats)
                        _FormatPill(format: format),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Jusqu\'à ${AppConstants.maxFileSizeLabel} par fichier',
                    style: context.texts.labelSmall?.copyWith(color: palette.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatPill extends StatelessWidget {
  final FileFormat format;

  const _FormatPill({required this.format});

  @override
  Widget build(BuildContext context) {
    final color = context.palette.forFormat(format);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        format.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }
}
