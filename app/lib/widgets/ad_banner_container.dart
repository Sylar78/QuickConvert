import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import '../providers/providers.dart';
import '../services/services.dart';

/// La bannière publicitaire des comptes gratuits.
///
/// Sur mobile elle affiche la vraie bannière AdMob — l'ancienne version
/// dessinait un [Placeholder] à la place, donc aucune impression n'était
/// jamais rendue. Sur le web, où AdMob n'existe pas, elle montre un espace
/// réservé qui se présente comme tel.
class AdBannerContainer extends StatefulWidget {
  const AdBannerContainer({super.key});

  @override
  State<AdBannerContainer> createState() => _AdBannerContainerState();
}

class _AdBannerContainerState extends State<AdBannerContainer> {
  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _loadAd();
  }

  Future<void> _loadAd() async {
    final ad = await AdmobService().loadBanner();
    if (mounted) setState(() => _ad = ad);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user.isPremium) return const SizedBox.shrink();

    final ad = _ad;
    if (kIsWeb || ad == null) return const _AdPlaceholder();

    return Container(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: ad),
    );
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
