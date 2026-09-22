import 'package:flutter_test/flutter_test.dart';
import 'package:quick_convert/core/constants.dart';
import 'package:quick_convert/models/premium_plan.dart';
import 'package:quick_convert/services/stripe_billing_service.dart';

/// Les formules doivent désigner la même chose des deux côtés : l'identifiant
/// de produit pour Google Play, le nom de plan pour Stripe. Une divergence
/// vendrait la mauvaise formule sans que rien ne plante.
void main() {
  test('chaque formule connaît son produit de store', () {
    expect(PremiumPlan.monthly.storeProductId, AppConstants.premiumMonthlyId);
    expect(PremiumPlan.yearly.storeProductId, AppConstants.premiumYearlyId);
  });

  test('les deux sens de conversion se répondent', () {
    for (final plan in PremiumPlan.values) {
      expect(PremiumPlan.fromApiName(plan.apiName), plan);
      expect(PremiumPlan.fromProductId(plan.storeProductId), plan);
    }
  });

  test('un nom inconnu ne devient pas une formule par défaut', () {
    expect(PremiumPlan.fromApiName('lifetime'), isNull);
    expect(PremiumPlan.fromApiName(null), isNull);
    expect(PremiumPlan.fromProductId('autre_produit'), isNull);
  });

  test('le prix Stripe s\'affiche à la française', () {
    // Stripe donne des centimes : 499 doit se lire « 4,99 € », pas « €4.99 »
    // ni « 499 ».
    const price = StripePrice(amount: 499, currency: 'eur');
    expect(price.label, contains('4,99'));
    expect(price.label, contains('€'));
  });

  test('un prix annuel garde ses milliers lisibles', () {
    const price = StripePrice(amount: 2499, currency: 'eur');
    expect(price.label, contains('24,99'));
  });
}
