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
  RewardedAd? _rewardedAd;

  // ─── IDs selon plateforme ─────────────────────────────────────────────────
  String get _bannerId => (!kIsWeb && Platform.isAndroid)
      ? AppConstants.admobBannerIdAndroid
      : AppConstants.admobBannerIdIos;

  String get _interstitialId => (!kIsWeb && Platform.isAndroid)
      ? AppConstants.admobInterstitialIdAndroid
      : AppConstants.admobInterstitialIdIos;

  /// Blocs de test publics de Google pour les annonces avec récompense.
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  /// Le bloc avec récompense, ou une chaîne vide s'il n'en existe pas : en
  /// production tant qu'il n'est pas créé dans AdMob, et toujours sur le web.
  String get _rewardedId {
    if (kIsWeb) return '';
    final android = Platform.isAndroid;
    final configured = android
        ? AppConstants.admobRewardedIdAndroid
        : AppConstants.admobRewardedIdIos;
    if (configured.isNotEmpty) return configured;
    if (!kDebugMode) return '';
    return android ? _testRewardedAndroid : _testRewardedIos;
  }

  /// Vrai si l'app peut proposer une vidéo contre des conversions.
  bool get rewardedAvailable => _rewardedId.isNotEmpty;

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
    unawaited(_loadRewarded());
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

  // ─── Avec récompense ──────────────────────────────────────────────────────
  Future<void> _loadRewarded() async {
    if (!rewardedAvailable || _rewardedAd != null) return;
    await RewardedAd.load(
      adUnitId: _rewardedId,
      request: adRequest,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) =>
            debugPrint('Rewarded failed: ${error.message}'),
      ),
    );
  }

  /// Montre une vidéo avec récompense. Renvoie vrai seulement si
  /// l'utilisateur l'a regardée jusqu'à la récompense ; faux si aucune
  /// n'était prête (une autre est alors chargée) ou s'il l'a fermée avant.
  Future<bool> showRewarded() async {
    final ad = _rewardedAd;
    if (ad == null) {
      unawaited(_loadRewarded());
      return false;
    }
    _rewardedAd = null;

    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_loadRewarded());
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(_loadRewarded());
        if (!done.isCompleted) done.complete(false);
      },
    );

    try {
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
    } catch (e) {
      debugPrint('Rewarded show error: $e');
      ad.dispose();
      return false;
    }
    return done.future;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
