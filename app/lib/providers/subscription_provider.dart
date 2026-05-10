import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../core/constants.dart';

enum SubscriptionStatus { idle, loading, success, error }

class SubscriptionProvider extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;

  SubscriptionStatus _status = SubscriptionStatus.idle;
  List<ProductDetails> _products = [];
  String? _error;
  bool _available = false;

  SubscriptionStatus get status => _status;
  List<ProductDetails> get products => _products;
  String? get error => _error;
  bool get isAvailable => _available;

  ProductDetails? get monthlyProduct => _products
      .where((p) => p.id == AppConstants.premiumMonthlyId)
      .firstOrNull;

  ProductDetails? get yearlyProduct => _products
      .where((p) => p.id == AppConstants.premiumYearlyId)
      .firstOrNull;

  Future<void> initialize() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    // Écouter les achats
    _iap.purchaseStream.listen(_handlePurchaseUpdate);

    await loadProducts();
  }

  Future<void> loadProducts() async {
    _status = SubscriptionStatus.loading;
    notifyListeners();

    try {
      final ids = {
        AppConstants.premiumMonthlyId,
        AppConstants.premiumYearlyId,
      };
      final response = await _iap.queryProductDetails(ids);

      if (response.error != null) {
        _error = response.error!.message;
        _status = SubscriptionStatus.error;
      } else {
        _products = response.productDetails;
        _status = SubscriptionStatus.idle;
      }
    } catch (e) {
      _error = 'Impossible de charger les offres';
      _status = SubscriptionStatus.error;
    }

    notifyListeners();
  }

  Future<void> purchaseMonthly(Function(DateTime) onSuccess) async {
    if (monthlyProduct == null) return;
    await _purchase(monthlyProduct!, onSuccess);
  }

  Future<void> purchaseYearly(Function(DateTime) onSuccess) async {
    if (yearlyProduct == null) return;
    await _purchase(yearlyProduct!, onSuccess);
  }

  Future<void> _purchase(ProductDetails product, Function(DateTime) onSuccess) async {
    _status = SubscriptionStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _error = 'Achat échoué: ${e.toString()}';
      _status = SubscriptionStatus.error;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.error) {
        _error = purchase.error?.message ?? 'Erreur d\'achat';
        _status = SubscriptionStatus.error;
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _status = SubscriptionStatus.success;
        // Activer le premium pour 30 jours (ou 365 pour annuel)
        final days = purchase.productID == AppConstants.premiumYearlyId ? 365 : 30;
        // L'activation réelle se fait via le callback dans l'UI
      }

      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
    notifyListeners();
  }
}
