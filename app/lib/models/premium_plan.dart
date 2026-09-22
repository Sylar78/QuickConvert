import '../core/constants.dart';

/// Les deux formules d'abonnement, indépendamment de qui les encaisse.
///
/// Google Play les connaît par un identifiant de produit, Stripe par un nom de
/// plan. Le reste de l'app ne manipule que cette énumération : c'est ce qui
/// permet à l'écran Premium d'être le même sur mobile et sur le web.
enum PremiumPlan {
  monthly,
  yearly;

  /// L'identifiant du produit dans Google Play et l'App Store.
  String get storeProductId => switch (this) {
        PremiumPlan.monthly => AppConstants.premiumMonthlyId,
        PremiumPlan.yearly => AppConstants.premiumYearlyId,
      };

  /// Le nom attendu par les fonctions `/api` de Stripe.
  String get apiName => name;

  String get title => switch (this) {
        PremiumPlan.monthly => 'Mensuel',
        PremiumPlan.yearly => 'Annuel',
      };

  String get period => switch (this) {
        PremiumPlan.monthly => 'par mois',
        PremiumPlan.yearly => 'par an',
      };

  /// Le prix montré tant que le store ou Stripe n'a pas répondu.
  String get fallbackPrice => switch (this) {
        PremiumPlan.monthly => AppConstants.fallbackMonthlyPrice,
        PremiumPlan.yearly => AppConstants.fallbackYearlyPrice,
      };

  static PremiumPlan? fromApiName(String? value) {
    for (final plan in PremiumPlan.values) {
      if (plan.apiName == value) return plan;
    }
    return null;
  }

  static PremiumPlan? fromProductId(String? value) {
    for (final plan in PremiumPlan.values) {
      if (plan.storeProductId == value) return plan;
    }
    return null;
  }
}
