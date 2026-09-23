import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../models/premium_plan.dart';
import '../services/services.dart';

/// Qui encaisse l'abonnement sur cette plateforme.
enum BillingBackend {
  /// Personne : ni store ni serveur de paiement configuré.
  none,

  /// Google Play ou l'App Store, via `in_app_purchase`.
  store,

  /// Stripe, via les fonctions `/api` déployées à côté de l'app web.
  stripe,
}

/// Ce que le moyen de paiement de la plateforme peut faire pour nous.
enum StoreAvailability {
  /// La connexion n'a pas encore abouti.
  checking,

  /// Aucun moyen de paiement sur cette plateforme.
  unsupported,

  /// Il y en a un, mais il ne répond pas : Play Services absent, appareil
  /// hors ligne, ou fonctions Stripe non configurées côté serveur.
  unavailable,

  /// Les formules sont souscriptibles.
  ready,
}

/// Où en est l'achat en cours.
enum PurchaseFlowStatus {
  idle,

  /// Les offres sont en cours de chargement.
  loadingProducts,

  /// Le paiement est parti et on attend la réponse. Sur Android, ça couvre
  /// aussi les paiements différés (virement, carte à valider), qui peuvent
  /// prendre plusieurs jours.
  pending,

  /// L'abonnement est accordé et persisté.
  success,

  /// L'utilisateur a fermé la page de paiement. Ce n'est pas une erreur.
  canceled,

  /// Le paiement a été refusé.
  failed,
}

/// Une formule telle qu'elle est proposée à l'utilisateur, quel que soit le
/// moyen de paiement derrière.
@immutable
class PlanOffer {
  final PremiumPlan plan;
  final String priceLabel;

  /// L'offre du store, quand c'est lui qui encaisse. Nulle sur le web.
  final ProductDetails? storeProduct;

  const PlanOffer({
    required this.plan,
    required this.priceLabel,
    this.storeProduct,
  });
}

/// Pilote les abonnements : chargement des offres, souscription, restauration,
/// et réconciliation de l'abonnement local avec ce que dit le payeur.
///
/// L'accès Premium n'est jamais accordé par l'interface : il est écrit ici, au
/// moment où le store ou Stripe confirme. Avant, cette classe recevait un
/// callback `onSuccess` qu'elle ne rappelait jamais — un achat réel débitait
/// l'utilisateur sans rien lui donner.
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({
    required VoidCallback onEntitlementChanged,
    EntitlementService? entitlements,
    StripeBillingService? stripe,
  })  : _onEntitlementChanged = onEntitlementChanged,
        _entitlements = entitlements ?? EntitlementService(),
        _stripe = stripe ?? StripeBillingService();

  final VoidCallback _onEntitlementChanged;
  final EntitlementService _entitlements;
  final StripeBillingService _stripe;

  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _purchases;
  bool _initialized = false;
  bool _disposed = false;

  BillingBackend _backend = BillingBackend.none;
  StoreAvailability _availability = StoreAvailability.checking;
  PurchaseFlowStatus _flow = PurchaseFlowStatus.idle;
  List<ProductDetails> _products = const [];
  Map<PremiumPlan, StripePrice> _stripePrices = const {};
  String? _message;

  /// Réconciliation avec le store en cours : voir [_runStoreRestore].
  Set<String>? _restoredIds;
  bool _storeAnswered = false;

  /// Vrai quand la réconciliation tourne au lancement, sans que l'utilisateur
  /// ait rien demandé : elle ne doit alors rien afficher.
  bool _silentRestore = false;

  BillingBackend get backend => _backend;
  StoreAvailability get availability => _availability;
  PurchaseFlowStatus get flow => _flow;

  /// Dernier message à montrer, ou `null` s'il n'y a rien à dire (une
  /// annulation, par exemple).
  String? get message => _message;

  bool get isReady => _availability == StoreAvailability.ready;

  /// Le store repond, mais il ne propose aucune formule : produits absents ou
  /// non publies dans la console, app installee autrement que par le store,
  /// ou panne passagere. Sans ce cas, l'ecran montrait un bouton grise et
  /// muet, ou l'utilisateur ne pouvait que deviner.
  bool get offersUnavailable =>
      _backend == BillingBackend.store &&
      _availability == StoreAvailability.ready &&
      _products.isEmpty &&
      _flow != PurchaseFlowStatus.loadingProducts;
  bool get isBusy =>
      _flow == PurchaseFlowStatus.pending ||
      _flow == PurchaseFlowStatus.loadingProducts;

  /// Vrai quand l'abonnement est attaché à ce navigateur et pas à un compte :
  /// l'écran Premium doit alors le dire, et proposer le code de reprise.
  bool get isBrowserBound => _backend == BillingBackend.stripe;

  /// Le code qui rattache l'abonnement Stripe à ce navigateur. À garder pour
  /// pouvoir le reprendre ailleurs, faute de comptes utilisateurs.
  String get restoreCode => _stripe.deviceId;

  /// Les deux formules, prix compris quand le payeur les a donnés.
  List<PlanOffer> get offers =>
      PremiumPlan.values.map(offerFor).toList(growable: false);

  PlanOffer offerFor(PremiumPlan plan) {
    final product = _storeProductFor(plan);
    if (product != null) {
      return PlanOffer(
        plan: plan,
        // Le prix vient du store : lui seul connaît la devise et la fiscalité
        // de l'utilisateur, et le Play Store exige que ce soit celui-là.
        priceLabel: product.price,
        storeProduct: product,
      );
    }

    final stripePrice = _stripePrices[plan];
    return PlanOffer(
      plan: plan,
      priceLabel: stripePrice?.label ?? plan.fallbackPrice,
    );
  }

  ProductDetails? _storeProductFor(PremiumPlan plan) {
    for (final product in _products) {
      if (product.id == plan.storeProductId) return product;
    }
    return null;
  }

  /// Vrai sur les plateformes où `in_app_purchase` a une implémentation.
  static bool get _storeSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Se connecte au payeur de la plateforme, charge les offres, puis vérifie
  /// que l'abonnement gardé en local est toujours actif.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (_storeSupported) {
      await _initializeStore();
    } else if (StripeBillingService.isConfigured) {
      await _initializeStripe();
    } else {
      _backend = BillingBackend.none;
      _availability = StoreAvailability.unsupported;
      _notify();
    }
  }

  /// Retente la connexion, après un échec.
  Future<void> retry() async {
    _initialized = false;
    _availability = StoreAvailability.checking;
    _message = null;
    _notify();
    await initialize();
  }

  // ───────────────────────────────────────────────────────────── Google Play

  Future<void> _initializeStore() async {
    _backend = BillingBackend.store;

    try {
      _iap = InAppPurchase.instance;
      if (!await _iap!.isAvailable()) {
        _iap = null;
        _availability = StoreAvailability.unavailable;
        _notify();
        return;
      }
    } catch (e) {
      debugPrint('Store indisponible : $e');
      _iap = null;
      _availability = StoreAvailability.unavailable;
      _notify();
      return;
    }

    // `retry()` peut repasser ici : sans annuler l'écoute précédente, chaque
    // achat serait traité autant de fois qu'on a retenté.
    await _purchases?.cancel();

    // Le flux porte tous les achats : ceux lancés ici, ceux restaurés, et ceux
    // qu'un paiement différé finit par valider alors que l'app a redémarré.
    _purchases = _iap!.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        _flow = PurchaseFlowStatus.failed;
        _message = "Le store a interrompu l'achat. Réessaie dans un moment.";
        _notify();
      },
    );

    _availability = StoreAvailability.ready;
    _notify();

    await _loadStoreProducts();
    await _runStoreRestore(userInitiated: false);
  }

  Future<void> _loadStoreProducts() async {
    final iap = _iap;
    if (iap == null) return;

    _flow = PurchaseFlowStatus.loadingProducts;
    _notify();

    try {
      final response = await iap.queryProductDetails(
        PremiumPlan.values.map((p) => p.storeProductId).toSet(),
      );

      if (response.productDetails.isNotEmpty) {
        _products = response.productDetails;
        _flow = PurchaseFlowStatus.idle;
      } else {
        // Offres introuvables : le plus souvent les produits ne sont pas
        // publiés dans la console du store, ou l'app n'est pas installée
        // depuis le store. L'utilisateur n'y peut rien, on le dit sans jargon.
        _message = response.error?.message ??
            'Les offres ne sont pas disponibles pour le moment.';
        _flow = PurchaseFlowStatus.failed;
      }
    } catch (e) {
      debugPrint('queryProductDetails: $e');
      _message = 'Impossible de charger les offres.';
      _flow = PurchaseFlowStatus.failed;
    }

    _notify();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      await _handlePurchase(purchase);
    }
    _notify();
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    final restoring = _restoredIds != null;
    if (restoring) _storeAnswered = true;

    switch (purchase.status) {
      case PurchaseStatus.pending:
        if (!_silentRestore) {
          _flow = PurchaseFlowStatus.pending;
          _message = null;
        }

      case PurchaseStatus.canceled:
        // Fermer la feuille de paiement n'est pas une erreur : on ne montre
        // rien, on remet juste le bouton à l'endroit.
        if (!_silentRestore) {
          _flow = PurchaseFlowStatus.canceled;
          _message = null;
        }

      case PurchaseStatus.error:
        // Une erreur pendant la vérification du lancement n'est pas une
        // erreur d'achat : l'utilisateur n'a rien demandé, on ne l'alarme pas.
        if (!_silentRestore) {
          _flow = PurchaseFlowStatus.failed;
          _message = _readableError(purchase.error);
        }

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        _restoredIds?.add(purchase.productID);

        // ── L'ordre compte ──────────────────────────────────────────────
        // L'abonnement est écrit sur le disque AVANT de dire au store que
        // l'achat est traité. Si l'app meurt entre les deux, le store
        // renverra l'achat au prochain lancement. Dans l'autre ordre, il le
        // considérerait comme livré et l'utilisateur aurait payé pour rien.
        await _entitlements.grant(
          productId: purchase.productID,
          source: _storeSource,
        );
        _onEntitlementChanged();

        // Une restauration silencieuse au lancement ne doit rien annoncer :
        // l'utilisateur n'a rien demandé.
        if (!restoring) {
          _flow = PurchaseFlowStatus.success;
          _message = purchase.status == PurchaseStatus.restored
              ? 'Abonnement restauré.'
              : 'Bienvenue dans QuickConvert Premium.';
        }
    }

    // Obligatoire pour tout achat qui le demande, y compris en erreur : sans
    // ça, Google Play rembourse automatiquement au bout de trois jours.
    if (purchase.pendingCompletePurchase) {
      try {
        await _iap?.completePurchase(purchase);
      } catch (e) {
        debugPrint('completePurchase: $e');
      }
    }
  }

  /// Redemande au store ses achats actifs et aligne l'abonnement local dessus.
  ///
  /// C'est la seule façon, sans serveur de validation, d'apprendre qu'un
  /// abonnement a été résilié ou non renouvelé : le store cesse simplement de
  /// le renvoyer. L'accès n'est donc retiré que si le store **a répondu** sans
  /// mentionner notre abonnement ; s'il ne répond pas, on garde l'accès tel
  /// quel, parce que couper le Premium d'un client qui paie est bien pire.
  Future<void> _runStoreRestore({required bool userInitiated}) async {
    final iap = _iap;
    if (iap == null) return;

    final local = _entitlements.read();
    // Une activation de développement ne vient d'aucun store : la confronter
    // au store la supprimerait à chaque lancement.
    if (local.source == EntitlementSource.debug) return;
    if (!userInitiated && !local.isActive) return;

    _restoredIds = <String>{};
    _storeAnswered = false;
    _silentRestore = !userInitiated;
    if (userInitiated) {
      _flow = PurchaseFlowStatus.pending;
      _message = null;
      _notify();
    }

    try {
      await iap.restorePurchases();
    } catch (e) {
      debugPrint('restorePurchases: $e');
      _restoredIds = null;
      _silentRestore = false;
      if (userInitiated) {
        _flow = PurchaseFlowStatus.failed;
        _message = "Le store n'a pas répondu. Réessaie dans un moment.";
        _notify();
      }
      return;
    }

    // Les achats restaurés arrivent par le flux, pas en valeur de retour : on
    // laisse au store le temps de les livrer avant de conclure.
    await Future<void>.delayed(AppConstants.restoreSettleDelay);
    if (_disposed) return;

    final restored = _restoredIds ?? const <String>{};
    final answered = _storeAnswered;
    _restoredIds = null;
    _silentRestore = false;

    final stillActive = PremiumPlan.values
        .any((plan) => restored.contains(plan.storeProductId));

    if (stillActive) {
      await _entitlements.touch();
      if (userInitiated) {
        _flow = PurchaseFlowStatus.success;
        _message = 'Abonnement restauré.';
      }
    } else if (answered) {
      if (local.isActive) {
        await _entitlements.revoke();
        _onEntitlementChanged();
      }
      if (userInitiated) {
        _flow = PurchaseFlowStatus.idle;
        _message = 'Aucun abonnement actif sur ce compte $_storeName.';
      }
    } else if (userInitiated) {
      _flow = PurchaseFlowStatus.failed;
      _message = "Le store n'a pas répondu. Réessaie dans un moment.";
    }

    _notify();
  }

  // ───────────────────────────────────────────────────────────────── Stripe

  Future<void> _initializeStripe() async {
    _backend = BillingBackend.stripe;
    _availability = StoreAvailability.ready;
    _flow = PurchaseFlowStatus.loadingProducts;
    _notify();

    final prices = await _stripe.fetchPrices();
    if (_disposed) return;

    _stripePrices = prices ?? const {};
    _flow = PurchaseFlowStatus.idle;
    // Sans tarif, il n'y a rien à vendre : mieux vaut l'annoncer que laisser
    // un bouton qui mènera à une erreur. L'abonnement déjà payé, lui, est
    // vérifié quand même juste en dessous.
    _availability = _stripePrices.isEmpty
        ? StoreAvailability.unavailable
        : StoreAvailability.ready;
    _notify();

    // Au retour du paiement, Stripe ajoute l'identifiant de session à l'URL :
    // il rend l'abonnement lisible tout de suite, sans attendre que l'index
    // de recherche de Stripe le voie.
    await _syncStripe(
      sessionId: StripeBillingService.checkoutSessionFromUrl,
      userInitiated: false,
    );
  }

  /// Demande à Stripe l'état de l'abonnement de ce navigateur et aligne
  /// l'abonnement local dessus.
  Future<void> _syncStripe({
    String? sessionId,
    required bool userInitiated,
  }) async {
    final local = _entitlements.read();
    if (local.source == EntitlementSource.debug) return;

    if (userInitiated) {
      _flow = PurchaseFlowStatus.pending;
      _message = null;
      _notify();
    }

    final result = await _stripe.fetchEntitlement(sessionId: sessionId);
    if (_disposed) return;

    switch (result.outcome) {
      case StripeLookup.active:
        final plan = result.plan ?? PremiumPlan.monthly;
        await _entitlements.grant(
          productId: plan.storeProductId,
          source: EntitlementSource.stripe,
          // Stripe, lui, connaît la fin de période : elle sert de filet, et
          // elle est rafraîchie à chaque lancement.
          expiresAt: result.currentPeriodEnd,
        );
        _onEntitlementChanged();
        if (userInitiated || sessionId != null) {
          _flow = PurchaseFlowStatus.success;
          _message = 'Bienvenue dans QuickConvert Premium.';
        }

      case StripeLookup.inactive:
        if (local.isActive && local.source == EntitlementSource.stripe) {
          await _entitlements.revoke();
          _onEntitlementChanged();
        }
        if (userInitiated) {
          _flow = PurchaseFlowStatus.idle;
          _message = 'Aucun abonnement actif pour ce navigateur.';
        }

      case StripeLookup.unknown:
        // Le serveur n'a pas répondu : surtout ne pas en conclure que
        // l'utilisateur n'est pas abonné.
        if (userInitiated) {
          _flow = PurchaseFlowStatus.failed;
          _message = 'Le service de paiement ne répond pas. Réessaie plus tard.';
        }
    }

    _notify();
  }

  /// Reprend un abonnement souscrit depuis un autre navigateur, à partir du
  /// code affiché sur l'appareil d'origine.
  ///
  /// C'est la contrepartie de l'absence de comptes : sans ce code, un
  /// abonnement resterait prisonnier du navigateur qui l'a payé.
  Future<void> restoreWithCode(String code) async {
    final cleaned = code.trim().toLowerCase();
    if (_backend != BillingBackend.stripe) return;

    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(cleaned)) {
      _flow = PurchaseFlowStatus.failed;
      _message = "Ce code n'a pas le bon format.";
      _notify();
      return;
    }

    _stripe.adoptDeviceId(cleaned);
    await _syncStripe(userInitiated: true);
  }

  // ────────────────────────────────────────────────────────────────── Commun

  /// Souscrit à une formule. Le résultat n'arrive pas au retour de cette
  /// méthode : sur mobile il vient du flux du store, sur le web l'utilisateur
  /// part sur la page de Stripe et l'app est rechargée à son retour.
  Future<void> buy(PremiumPlan plan) async {
    switch (_backend) {
      case BillingBackend.store:
        await _buyFromStore(plan);
      case BillingBackend.stripe:
        await _buyFromStripe(plan);
      case BillingBackend.none:
        return;
    }
  }

  Future<void> _buyFromStore(PremiumPlan plan) async {
    final iap = _iap;
    final product = _storeProductFor(plan);
    if (iap == null || product == null) {
      // Filet de securite : l'ecran desactive deja le bouton dans ce cas.
      // Sortir en silence laisserait croire a un clic ignore.
      _flow = PurchaseFlowStatus.failed;
      _message = "Cette formule n'est pas proposee par le store pour le moment.";
      _notify();
      return;
    }

    _flow = PurchaseFlowStatus.pending;
    _message = null;
    _notify();

    try {
      // Un abonnement s'achète en « non consommable » : il ne se rachète pas,
      // il se renouvelle. `buyConsumable` le rendrait rachetable en boucle.
      final started = await iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _flow = PurchaseFlowStatus.failed;
        _message = "Le store n'a pas pu ouvrir le paiement.";
        _notify();
      }
    } catch (e) {
      debugPrint('buyNonConsumable: $e');
      _flow = PurchaseFlowStatus.failed;
      _message = "L'achat n'a pas pu démarrer.";
      _notify();
    }
  }

  Future<void> _buyFromStripe(PremiumPlan plan) async {
    _flow = PurchaseFlowStatus.pending;
    _message = null;
    _notify();

    final url = await _stripe.startCheckout(plan);
    if (_disposed) return;

    if (url == null) {
      _flow = PurchaseFlowStatus.failed;
      _message = "Le paiement n'a pas pu s'ouvrir. Réessaie dans un moment.";
      _notify();
      return;
    }

    // `_self` : on quitte l'app pour la page de Stripe, et on y revient par
    // l'URL de succès. Un nouvel onglet serait bloqué par les navigateurs,
    // l'appel venant d'une réponse réseau et non du clic lui-même.
    final opened = await launchUrl(
      Uri.parse(url),
      webOnlyWindowName: '_self',
      mode: LaunchMode.platformDefault,
    );
    if (_disposed) return;

    if (!opened) {
      _flow = PurchaseFlowStatus.failed;
      _message = "Le paiement n'a pas pu s'ouvrir.";
      _notify();
    }
  }

  /// Ouvre la page où l'utilisateur gère sa carte et résilie : celle du store
  /// sur mobile, le portail client Stripe sur le web.
  ///
  /// Vendre un abonnement sans chemin de résiliation n'est pas une option, et
  /// le Play Store le refuse explicitement.
  Future<bool> openManageSubscription() async {
    if (_backend == BillingBackend.stripe) {
      final url = await _stripe.openPortal();
      if (url == null) return false;
      return launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    }

    final url = defaultTargetPlatform == TargetPlatform.iOS
        ? AppConstants.appStoreSubscriptionsUrl
        : AppConstants.playSubscriptionsUrl;
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Restauration demandée par l'utilisateur.
  Future<void> restorePurchases() async {
    switch (_backend) {
      case BillingBackend.store:
        await _runStoreRestore(userInitiated: true);
      case BillingBackend.stripe:
        await _syncStripe(userInitiated: true);
      case BillingBackend.none:
        return;
    }
  }

  EntitlementSource get _storeSource =>
      defaultTargetPlatform == TargetPlatform.android
          ? EntitlementSource.playStore
          : EntitlementSource.appStore;

  String get _storeName => defaultTargetPlatform == TargetPlatform.android
      ? 'Google Play'
      : 'App Store';

  static String _readableError(IAPError? error) {
    final raw = error?.message;
    if (raw == null || raw.isEmpty) return "L'achat n'a pas abouti.";
    return "L'achat n'a pas abouti : $raw";
  }

  /// Efface le message après qu'il a été montré, pour ne pas le rejouer au
  /// prochain rebuild de l'écran.
  void consumeMessage() {
    if (_message == null) return;
    _message = null;
    if (_flow == PurchaseFlowStatus.success ||
        _flow == PurchaseFlowStatus.failed ||
        _flow == PurchaseFlowStatus.canceled) {
      _flow = PurchaseFlowStatus.idle;
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Sans ça, chaque écoute survit au provider et les achats sont traités
    // plusieurs fois.
    _purchases?.cancel();
    super.dispose();
  }
}
