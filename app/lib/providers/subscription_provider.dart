import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/constants.dart';
import '../services/services.dart';

/// Ce que le store de la plateforme peut faire pour nous.
enum StoreAvailability {
  /// La connexion au store n'a pas encore abouti.
  checking,

  /// Il n'y a pas de store sur cette plateforme. C'est le cas du web : ni
  /// Google Play ni l'App Store n'y existent, et encaisser une carte
  /// demanderait un prestataire de paiement et un serveur pour valider
  /// l'abonnement — la clé secrète ne peut pas vivre dans le bundle.
  unsupported,

  /// Un store existe mais ne répond pas : Play Services absent, appareil
  /// hors ligne, ou build installé hors du store.
  unavailable,

  /// Le store répond, les offres sont achetables.
  ready,
}

/// Où en est l'achat en cours.
enum PurchaseFlowStatus {
  idle,

  /// Les offres sont en cours de chargement depuis le store.
  loadingProducts,

  /// Le paiement est parti et on attend la réponse du store. Sur Android, ça
  /// couvre aussi les paiements différés (virement, carte à valider), qui
  /// peuvent prendre plusieurs jours.
  pending,

  /// Le store a confirmé : l'abonnement est accordé et persisté.
  success,

  /// L'utilisateur a fermé la feuille de paiement. Ce n'est pas une erreur.
  canceled,

  /// Le store a refusé l'achat.
  failed,
}

/// Pilote les abonnements : chargement des offres, achat, restauration, et
/// réconciliation de l'abonnement local avec ce que dit le store.
///
/// L'accès Premium n'est jamais accordé depuis l'interface : il est écrit par
/// [_handlePurchase], au moment où le store confirme l'achat. Avant, cette
/// classe recevait un callback `onSuccess` qu'elle ne rappelait jamais — un
/// achat réel débitait l'utilisateur sans rien lui donner.
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({
    required VoidCallback onEntitlementChanged,
    EntitlementService? entitlements,
  })  : _onEntitlementChanged = onEntitlementChanged,
        _entitlements = entitlements ?? EntitlementService();

  final VoidCallback _onEntitlementChanged;
  final EntitlementService _entitlements;

  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _purchases;
  bool _initialized = false;
  bool _disposed = false;

  StoreAvailability _availability = StoreAvailability.checking;
  PurchaseFlowStatus _flow = PurchaseFlowStatus.idle;
  List<ProductDetails> _products = const [];
  String? _message;

  /// Réconciliation en cours : voir [_runRestore].
  Set<String>? _restoredIds;
  bool _storeAnswered = false;

  /// Vrai quand la réconciliation tourne au lancement, sans que
  /// l'utilisateur ait rien demandé : elle ne doit alors rien afficher.
  bool _silentRestore = false;

  StoreAvailability get availability => _availability;
  PurchaseFlowStatus get flow => _flow;
  List<ProductDetails> get products => _products;

  /// Dernier message à montrer à l'utilisateur, ou `null` s'il n'y a rien à
  /// dire (une annulation, par exemple).
  String? get message => _message;

  bool get isReady => _availability == StoreAvailability.ready;
  bool get isBusy =>
      _flow == PurchaseFlowStatus.pending ||
      _flow == PurchaseFlowStatus.loadingProducts;

  ProductDetails? get monthlyProduct => _productById(AppConstants.premiumMonthlyId);
  ProductDetails? get yearlyProduct => _productById(AppConstants.premiumYearlyId);

  ProductDetails? _productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
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

  /// Se connecte au store, charge les offres, puis vérifie que l'abonnement
  /// gardé en local est toujours actif. Sans effet si déjà appelée.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!_storeSupported) {
      _availability = StoreAvailability.unsupported;
      _notify();
      return;
    }

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

    await loadProducts();
    await _runRestore(userInitiated: false);
  }

  /// Retente la connexion au store, après un échec.
  Future<void> retry() async {
    _initialized = false;
    _availability = StoreAvailability.checking;
    _message = null;
    _notify();
    await initialize();
  }

  Future<void> loadProducts() async {
    final iap = _iap;
    if (iap == null) return;

    _flow = PurchaseFlowStatus.loadingProducts;
    _notify();

    try {
      final response = await iap.queryProductDetails(<String>{
        AppConstants.premiumMonthlyId,
        AppConstants.premiumYearlyId,
      });

      if (response.productDetails.isNotEmpty) {
        _products = response.productDetails;
        _flow = PurchaseFlowStatus.idle;
      } else {
        // Offres introuvables : le plus souvent les produits ne sont pas
        // publiés dans la console du store, ou l'app n'est pas installée
        // depuis le store. L'utilisateur n'y peut rien, on le dit sans jargon.
        _message = response.error?.message ??
            "Les offres ne sont pas disponibles pour le moment.";
        _flow = PurchaseFlowStatus.failed;
      }
    } catch (e) {
      debugPrint('queryProductDetails: $e');
      _message = 'Impossible de charger les offres.';
      _flow = PurchaseFlowStatus.failed;
    }

    _notify();
  }

  /// Lance l'achat d'une offre. Le résultat n'arrive pas au retour de cette
  /// méthode mais par le flux d'achats, d'où l'absence de valeur de retour.
  Future<void> buy(ProductDetails product) async {
    final iap = _iap;
    if (iap == null) return;

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

  /// Restauration demandée par l'utilisateur, depuis l'écran Premium.
  Future<void> restorePurchases() => _runRestore(userInitiated: true);

  /// Redemande au store ses achats actifs et aligne l'abonnement local dessus.
  ///
  /// C'est la seule façon, sans serveur de validation, d'apprendre qu'un
  /// abonnement a été résilié ou non renouvelé : le store cesse simplement de
  /// le renvoyer. L'accès n'est donc retiré que si le store **a répondu** sans
  /// mentionner notre abonnement ; s'il ne répond pas (hors ligne, Play
  /// Services en vrac), on garde l'accès tel quel, parce que couper le Premium
  /// d'un client qui paie est bien pire que de le laisser un jour de trop.
  Future<void> _runRestore({required bool userInitiated}) async {
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

    final stillActive = restored.contains(local.productId) ||
        restored.contains(AppConstants.premiumMonthlyId) ||
        restored.contains(AppConstants.premiumYearlyId);

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
        _message = "Aucun abonnement actif sur ce compte $_storeName.";
      }
    } else if (userInitiated) {
      _flow = PurchaseFlowStatus.failed;
      _message = "Le store n'a pas répondu. Réessaie dans un moment.";
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
          source: _sourceForPlatform,
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

  EntitlementSource get _sourceForPlatform =>
      defaultTargetPlatform == TargetPlatform.android
          ? EntitlementSource.playStore
          : EntitlementSource.appStore;

  String get _storeName => defaultTargetPlatform == TargetPlatform.android
      ? 'Google Play'
      : 'App Store';

  static String _readableError(IAPError? error) {
    final raw = error?.message;
    if (raw == null || raw.isEmpty) {
      return "L'achat n'a pas abouti.";
    }
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
