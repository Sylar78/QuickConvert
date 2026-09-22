import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/models.dart';
import 'format_badge.dart';

/// Le choix du format de sortie, déduit du fichier déposé.
///
/// Remplace les sept tuiles de l'ancien accueil : l'utilisateur ne traduit
/// plus son intention en couple de formats, il choisit une destination parmi
/// celles que son fichier autorise.
class OutputFormatSelector extends StatelessWidget {
  final List<ConversionRoute> routes;
  final ConversionRoute selected;
  final ValueChanged<ConversionRoute> onSelected;

  const OutputFormatSelector({
    super.key,
    required this.routes,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Un seul débouché : ce n'est pas un choix, on l'annonce.
    if (routes.length == 1) {
      return _SingleRoute(route: routes.first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Convertir en', style: context.texts.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final route in routes)
              _RouteChip(
                route: route,
                isSelected: route.type == selected.type,
                onTap: () => onSelected(route),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(selected.description, style: context.texts.bodySmall),
      ],
    );
  }
}

class _RouteChip extends StatelessWidget {
  final ConversionRoute route;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteChip({
    required this.route,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final formatColor = palette.forFormat(route.to);

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Convertir en ${route.to.label}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AnimatedContainer(
            duration: AppDuration.fast,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isSelected ? colors.primaryContainer : colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isSelected ? colors.primary : palette.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FormatStyle.iconFor(route.to), size: 17, color: formatColor),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  route.to.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? colors.onPrimaryContainer : colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleRoute extends StatelessWidget {
  final ConversionRoute route;

  const _SingleRoute({required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.palette.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          FormatTransition(
            from: route.from,
            to: route.to,
            size: FormatBadgeSize.small,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(route.description, style: context.texts.bodySmall),
          ),
        ],
      ),
    );
  }
}
