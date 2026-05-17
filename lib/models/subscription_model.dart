enum SubscriptionPlan { free, premiumMonthly, premiumYearly }

class SubscriptionModel {
  final SubscriptionPlan plan;
  final double price;
  final String currency;
  final DateTime? expiresAt;
  final bool isActive;

  const SubscriptionModel({
    required this.plan,
    required this.price,
    required this.currency,
    this.expiresAt,
    this.isActive = false,
  });

  String get planName {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Gratuit';
      case SubscriptionPlan.premiumMonthly:
        return 'Premium Mensuel';
      case SubscriptionPlan.premiumYearly:
        return 'Premium Annuel';
    }
  }

  String get priceLabel {
    if (plan == SubscriptionPlan.free) return 'Gratuit';
    return '${price.toStringAsFixed(2)} $currency/mois';
  }

  List<String> get features {
    switch (plan) {
      case SubscriptionPlan.free:
        return [
          '5 conversions par jour',
          'Publicités discrètes',
          'Formats principaux',
        ];
      case SubscriptionPlan.premiumMonthly:
      case SubscriptionPlan.premiumYearly:
        return [
          'Conversions illimitées',
          'Sans publicité',
          'OCR (texte depuis photo)',
          'Compression HD',
          'Priorité serveur',
          'Support prioritaire',
        ];
    }
  }

  static const SubscriptionModel free = SubscriptionModel(
    plan: SubscriptionPlan.free,
    price: 0,
    currency: 'EUR',
  );

  static const SubscriptionModel monthly = SubscriptionModel(
    plan: SubscriptionPlan.premiumMonthly,
    price: 4.99,
    currency: 'EUR',
  );

  static const SubscriptionModel yearly = SubscriptionModel(
    plan: SubscriptionPlan.premiumYearly,
    price: 2.99, // 35.88/year = ~2.99/month
    currency: 'EUR',
  );
}
