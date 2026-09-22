import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/models.dart';
import 'format_badge.dart';

/// Un fichier sélectionné, avec son format, sa taille et sa croix de retrait.
///
/// La croix retire vraiment le fichier : [SourceFile] porte à la fois le
/// chemin et les octets, donc il n'y a plus deux listes à garder synchronisées.
class SourceFileTile extends StatelessWidget {
  final SourceFile file;
  final FileFormat format;
  final VoidCallback onRemove;

  const SourceFileTile({
    super.key,
    required this.file,
    required this.format,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          FormatBadge(format: format, size: FormatBadgeSize.small),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: context.texts.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(formatBytes(file.sizeBytes), style: context.texts.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            color: palette.textMuted,
            tooltip: 'Retirer ${file.name}',
          ),
        ],
      ),
    );
  }
}
