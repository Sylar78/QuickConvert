import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_convert/providers/subscription_provider.dart';
import 'package:quick_convert/core/core.dart';
import 'package:quick_convert/widgets/quota_card.dart';

void main() {
  group('premiumSellable', () {
    test('iPhone sans offre chargée : Premium masqué (règle 3.1.1)', () {
      expect(
        SubscriptionProvider.premiumSellable(
          platform: TargetPlatform.iOS,
          backend: BillingBackend.store,
          hasProducts: false,
        ),
        isFalse,
      );
    });

    test('iPhone avec offres : Premium visible', () {
      expect(
        SubscriptionProvider.premiumSellable(
          platform: TargetPlatform.iOS,
          backend: BillingBackend.store,
          hasProducts: true,
        ),
        isTrue,
      );
    });

    test('Android et web gardent Premium, même sans offre', () {
      expect(
        SubscriptionProvider.premiumSellable(
          platform: TargetPlatform.android,
          backend: BillingBackend.store,
          hasProducts: false,
        ),
        isTrue,
      );
      expect(
        SubscriptionProvider.premiumSellable(
          platform: TargetPlatform.iOS,
          backend: BillingBackend.none,
          hasProducts: false,
        ),
        isTrue,
      );
    });
  });

  testWidgets('la carte de quota ne parle pas de Premium sans onUpgrade',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: QuotaCard(remaining: 0, total: 3)),
    ));
    expect(find.textContaining('Premium'), findsNothing);
    expect(find.text('Reviens demain'), findsOneWidget);
  });
}
