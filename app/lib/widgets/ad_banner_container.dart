import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import '../providers/providers.dart';
import '../services/services.dart';

/// La bannière publicitaire des comptes gratuits.
///
/// Elle se construit sur les rappels du SDK plutôt que sur une attente fixe :
/// la version précédente renonçait au bout de deux secondes et n'affichait
/// plus jamais rien, ce qui rendait invisible toute annonce un peu lente à
/// venir. Elle possède sa propre annonce, parce qu'un `BannerAd` ne peut être
/// attaché qu'à un seul `AdWidget` à la fois.
///
/// [showPlaceholder] décide de ce qu'on fait quand aucune annonce n'arrive :
/// un espace réservé qui s'annonce comme tel là où la place est prévue, ou
/// rien du tout là où un trou se verrait, comme sous un résultat.
class AdBannerContainer extends StatefulWidget {
  final bool showPlaceholder;

  const AdBannerContainer({super.key, this.showPlaceholder = true});

  @override
  State<AdBannerContainer> createState() => _AdBannerContainerState();
}

class _AdBannerContainerState extends State<AdBannerContainer> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _load();
  }

  void _load() {
    _ad = AdmobService().buildBanner(
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // Le plus souvent : bloc d'annonces trop récent, ou aucune annonce
          // à servir pour ce profil. Rien à faire, et surtout rien à montrer.
          debugPrint('Bannière non chargée : ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad!.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user.isPremium) return const SizedBox.shrink();

    final ad = _ad;
    if (!kIsWeb && _loaded && ad != null) {
      return SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    }

    return widget.showPlaceholder
        ? const _AdPlaceholder()
        : const SizedBox.shrink();
  }
}

class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      label: 'Emplacement publicitaire',
      excludeSemantics: true,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: palette.sunken,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.lg),
            Icon(Icons.campaign_outlined, size: 18, color: palette.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Espace publicitaire',
                style: context.texts.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/premium'),
              child: const Text('Retirer'),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
