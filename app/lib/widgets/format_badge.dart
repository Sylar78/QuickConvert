import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/models.dart';

/// La pastille d'un format de fichier : icône, libellé, couleur du format.
/// Le même objet sert dans la grille d'accueil, la liste de fichiers,
/// l'historique et le sélecteur de sortie, aux trois tailles.
enum FormatBadgeSize { small, medium, large }

class FormatBadge extends StatelessWidget {
  final FileFormat format;
  final FormatBadgeSize size;
  final bool showLabel;

  const FormatBadge({
    super.key,
    required this.format,
    this.size = FormatBadgeSize.medium,
    this.showLabel = true,
  });

  double get _box => switch (size) {
        FormatBadgeSize.small => 36,
        FormatBadgeSize.medium => 46,
        FormatBadgeSize.large => 62,
      };

  double get _icon => switch (size) {
        FormatBadgeSize.small => 18,
        FormatBadgeSize.medium => 22,
        FormatBadgeSize.large => 28,
      };

  double get _text => switch (size) {
        FormatBadgeSize.small => 9,
        FormatBadgeSize.medium => 10,
        FormatBadgeSize.large => 11.5,
      };

  @override
  Widget build(BuildContext context) {
    final color = context.palette.forFormat(format);

    return Semantics(
      label: 'Format ${format.label}',
      excludeSemantics: true,
      child: Container(
        width: _box,
        height: _box,
        decoration: BoxDecoration(
          color: color.withAlpha(31),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withAlpha(61)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FormatStyle.iconFor(format), size: _icon, color: color),
            if (showLabel) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                format.label,
                style: TextStyle(
                  fontSize: _text,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// « JPG → PDF » en pastilles, avec la flèche au milieu.
class FormatTransition extends StatelessWidget {
  final FileFormat from;
  final FileFormat to;
  final FormatBadgeSize size;

  const FormatTransition({
    super.key,
    required this.from,
    required this.to,
    this.size = FormatBadgeSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${from.label} vers ${to.label}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FormatBadge(format: from, size: size),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: context.palette.textMuted,
            ),
          ),
          FormatBadge(format: to, size: size),
        ],
      ),
    );
  }
}
