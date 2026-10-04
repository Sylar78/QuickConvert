import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants.dart';

class AdmobService {
  static final AdmobService _instance = AdmobService._internal();
  factory AdmobService() => _instance;
  AdmobService._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  // ─── IDs selon plateforme ─────────────────────────────────────────────────
  String get _bannerId => (!kIsWeb && Platform.isAndroid)
      ? AppConstants.admobBannerIdAndroid
      : AppConstants.admobBannerIdIos;

  String get _interstitialId => (!kIsWeb && Platform.isAndroid)
      ? AppConstants.admobInterstitialIdAndroid
      : AppConstants.admobInterstitialIdIos;

  // ─── Requete d'annonce ────────────────────────────────────────────────────
  //
  // Toutes les annonces de QuickConvert sont non personnalisees : elles ne
  // s'appuient sur aucun historique de l'utilisateur. C'est ce qui dispense
  // l'app de la demande d'autorisation de suivi d'iOS (ATT) et de la cle
  // `NSUserTrackingUsageDescription` — sans ce choix, Apple exigerait les
  // deux, et AdMob servirait quand meme des annonces non personnalisees a
  // tous ceux qui refusent.
  //
  // Une seule requete partagee : si l'une des deux annonces l'oubliait, elle
  // repasserait en personnalisee sans que rien ne le signale. Publique pour
  // que ce choix soit verifiable par un test.
  static const AdRequest adRequest = AdRequest(nonPersonalizedAds: true);

  // ─── Initialisation ───────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    await _loadInterstitial();
  }

  // ─── Banniere ─────────────────────────────────────────────────────────────
  //
  // La banniere appartient au widget qui l'affiche, pas a ce service : deux
  // ecrans peuvent en montrer une en meme temps, et un `BannerAd` ne peut
  // etre attache qu'a un seul `AdWidget`. La version precedente en gardait
  // une seule ici, et attendait son chargement deux secondes avant de
  // renoncer definitivement — une annonce un peu lente ne s'affichait donc
  // jamais, sans que rien ne le signale.
  BannerAd buildBanner({required BannerAdListener listener}) => BannerAd(
        adUnitId: _bannerId,
        size: AdSize.banner,
        request: adRequest,
        listener: listener,
      );

  // ─── Interstitiel ─────────────────────────────────────────────────────────
  Future<void> _loadInterstitial() async {
    if (kIsWeb) return;
    await InterstitialAd.load(
      adUnitId: _interstitialId,
      request: adRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed: ${error.message}');
          _isInterstitialReady = false;
        },
      ),
    );
  }

  /// Affiche l'interstitiel s'il est prêt. Renvoie vrai s'il s'est affiché.
  ///
  /// Ne bloque jamais l'appelant sur le chargement : sans annonce prête, on
  /// renvoie faux tout de suite et on en recharge une pour la prochaine fois.
  /// Rien n'existe sur le web, où les bannières restent seules.
  Future<bool> showInterstitial() async {
    if (kIsWeb) return false;
    final ad = _interstitialAd;
    if (!_isInterstitialReady || ad == null) {
      unawaited(_loadInterstitial());
      return false;
    }

    _interstitialAd = null;
    _isInterstitialReady = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
      },
    );

    try {
      await ad.show();
      return true;
    } catch (e) {
      debugPrint('Interstitial show error: $e');
      return false;
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}
