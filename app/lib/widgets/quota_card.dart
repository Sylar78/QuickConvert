import 'package:flutter/material.dart';
import '../core/core.dart';

/// Le quota gratuit du jour.
///
/// Le chiffre vient de l'historique persisté, pas d'un compteur en mémoire :
/// c'est exactement celui que la conversion vérifiera.
class QuotaCard extends StatelessWidget {
  final int remaining;
  final int total;
  /// `null` quand Premium ne peut pas être vendu ici (iPhone sans offre) : la
  /// carte n'en parle alors plus.
  final VoidCallback? onUpgrade;

  /// Propose une vidéo contre [videoBonus] conversions. `null` quand aucune
  /// n'est disponible : bloc publicitaire absent, web, ou plafond du jour.
  final VoidCallback? onWatchVideo;
  final int videoBonus;

  const QuotaCard({
    super.key,
    required this.remaining,
    required this.total,
    this.onUpgrade,
    this.onWatchVideo,
    this.videoBonus = 0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;
    final exhausted = remaining == 0;
    final low = remaining <= 1;

    final accent = exhausted
        ? colors.error
        : low
            ? palette.warning
            : colors.primary;

    return Semantics(
      label: exhausted
          ? 'Limite quotidienne atteinte'
          : '$remaining conversions gratuites restantes sur $total',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onUpgrade,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: total == 0 ? 0 : remaining / total,
                              strokeWidth: 3.5,
                              strokeCap: StrokeCap.round,
                              backgroundColor: palette.sunken,
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                          Text(
                            '$remaining',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exhausted
                                ? 'Limite du jour atteinte'
                                : remaining > 1
                                    ? '$remaining conversions restantes'
                                    : 'Dernière conversion gratuite',
                            style: context.texts.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            exhausted
                                ? switch ((onWatchVideo != null, onUpgrade != null)) {
                                    (true, true) =>
                                      'Regarde une vidéo ou passe à Premium',
                                    (true, false) =>
                                      'Regarde une vidéo pour continuer',
                                    (false, true) =>
                                      'Passe à Premium pour continuer',
                                    (false, false) => 'Reviens demain',
                                  }
                                : total > AppConstants.freeConversionsPerDay
                                ? '${AppConstants.freeConversionsPerDay} par jour, '
                                    '+${total - AppConstants.freeConversionsPerDay} '
                                    'grâce aux vidéos'
                                : '$total par jour, sans compte',
                            style: context.texts.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (onUpgrade != null)
                      Icon(Icons.chevron_right_rounded,
                          color: palette.textMuted),
                  ],
                ),
                if (onWatchVideo != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonalIcon(
                    onPressed: onWatchVideo,
                    icon:
                        const Icon(Icons.play_circle_outline_rounded, size: 20),
                    label:
                        Text('Regarder une vidéo · +$videoBonus conversions'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
