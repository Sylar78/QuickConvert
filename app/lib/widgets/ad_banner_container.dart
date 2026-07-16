import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import '../providers/providers.dart';
import '../services/services.dart';

/// Widget intelligent qui affiche une bannière AdMob (natif)
/// ou une fausse bannière de prévisualisation (web/debug).
/// Se cache automatiquement si l'utilisateur est premium.
class AdBannerContainer extends StatefulWidget {
  const AdBannerContainer({super.key});

  @override
  State<AdBannerContainer> createState() => _AdBannerContainerState();
}

class _AdBannerContainerState extends State<AdBannerContainer> {
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Sur web, on affiche directement la fausse bannière
      setState(() => _isLoaded = true);
    } else {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final ad = await AdmobService().loadBanner();
    if (mounted && ad != null) {
      setState(() => _isLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user.isPremium || !_isLoaded) {
      return const SizedBox.shrink();
    }

    // Sur web ou en debug, afficher une fausse bannière
    if (kIsWeb) {
      return _FakeAdBanner();
    }

    final bannerAd = AdmobService().bannerAd;
    if (bannerAd == null) return _FakeAdBanner();

    return Container(
      width: bannerAd.size.width.toDouble(),
      height: bannerAd.size.height.toDouble(),
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: const Placeholder(), // AdWidget nécessite un vrai ad
      ),
    );
  }
}

/// Fausse bannière publicitaire pour la prévisualisation
class _FakeAdBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(12),
            AppColors.accent.withAlpha(15),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(25)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.ads_click_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Publicité — QuickConvert',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Passe à Premium pour supprimer les pubs',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Ad',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
