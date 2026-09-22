import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/core.dart';
import '../models/models.dart';
import 'format_badge.dart';

/// Une ligne d'historique.
///
/// En mode [dense] (aperçu sur l'écran de conversion), la ligne n'est pas
/// balayable : on ne supprime que depuis l'onglet Historique.
class HistoryItem extends StatelessWidget {
  final ConversionRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool dense;

  const HistoryItem({
    super.key,
    required this.record,
    this.onTap,
    this.onDelete,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = _buildTile(context);
    if (dense || onDelete == null) return tile;

    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: context.colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: context.colors.onErrorContainer),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: tile,
    );
  }

  Widget _buildTile(BuildContext context) {
    final palette = context.palette;
    final route = record.conversionType.route;
    // Format sans locale : `initializeDateFormatting` n'est pas appelé au
    // démarrage, et un DateFormat localisé lèverait une exception.
    final date = DateFormat('dd/MM/yy HH:mm').format(record.createdAt);

    return Semantics(
      button: onTap != null,
      label: '${record.inputFileName}, ${route.label}, '
          '${record.isSuccess ? 'réussie' : 'échouée'}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                FormatBadge(format: route.from, size: FormatBadgeSize.small),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.inputFileName,
                        style: context.texts.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${route.label} · ${record.formattedSize} · $date',
                        style: context.texts.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  record.isSuccess
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color: record.isSuccess ? palette.success : context.colors.error,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
