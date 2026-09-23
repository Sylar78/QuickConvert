import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants.dart';

class AdmobService {
  static final AdmobService _instance = AdmobService._internal();
  factory AdmobService() => _instance;
  AdmobService._internal();

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerLoaded = false;
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

  // ─── Banner ───────────────────────────────────────────────────────────────
  Future<BannerAd?> loadBanner() async {
    if (kIsWeb) return null;
    _isBannerLoaded = false;

    final completer = _BannerCompleter();

    _bannerAd = BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: adRequest,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _isBannerLoaded = true;
          completer.complete(_bannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed: ${error.message}');
          ad.dispose();
          completer.complete(null);
        },
      ),
    );

    await _bannerAd!.load();
    return completer.future;
  }

  bool get isBannerLoaded => _isBannerLoaded;
  BannerAd? get bannerAd => _bannerAd;

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

  Future<void> showInterstitial({VoidCallback? onDismissed}) async {
    if (kIsWeb) {
      onDismissed?.call();
      return;
    }
    if (!_isInterstitialReady || _interstitialAd == null) {
      onDismissed?.call();
      await _loadInterstitial();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isInterstitialReady = false;
        _loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isInterstitialReady = false;
        _loadInterstitial();
        onDismissed?.call();
      },
    );

    await _interstitialAd!.show();
    _interstitialAd = null;
  }

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
  }
}

/// Petit helper pour attendre le chargement du banner de manière async
class _BannerCompleter {
  BannerAd? _result;
  bool _completed = false;
  final List<Function(BannerAd?)> _listeners = [];

  void complete(BannerAd? ad) {
    _result = ad;
    _completed = true;
    for (final l in _listeners) {
      l(ad);
    }
  }

  Future<BannerAd?> get future async {
    if (_completed) return _result;
    await Future.delayed(const Duration(seconds: 2));
    return _result;
  }
}
