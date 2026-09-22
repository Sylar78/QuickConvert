import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/premium_plan.dart';

/// Ce que Stripe a répondu à la question « cet appareil est-il abonné ? ».
enum StripeLookup {
  /// Un abonnement est en cours.
  active,

  /// Stripe a répondu, et il n'y en a pas.
  inactive,

  /// Stripe n'a pas répondu. Surtout pas la même chose qu'« inactif » : sur
  /// ce résultat-là, l'app ne touche pas à l'abonnement qu'elle a en local.
  unknown,
}

@immutable
class StripeEntitlement {
  final StripeLookup outcome;
  final PremiumPlan? plan;
  final DateTime? currentPeriodEnd;

  const StripeEntitlement(this.outcome, {this.plan, this.currentPeriodEnd});

  static const StripeEntitlement unknown =
      StripeEntitlement(StripeLookup.unknown);
  static const StripeEntitlement inactive =
      StripeEntitlement(StripeLookup.inactive);
}

/// Le prix affiché pour une formule, tel que Stripe le facture.
@immutable
class StripePrice {
  /// En centimes, comme Stripe les donne.
  final int amount;
  final String currency;

  const StripePrice({required this.amount, required this.currency});

  /// Mise en forme à la française, comme le reste de l'app : sans locale
  /// explicite, `intl` retombe sur en_US et afficherait « €4.99 » au lieu de
  /// « 4,99 € ». Le formatage des nombres, contrairement à celui des dates,
  /// ne demande aucune initialisation asynchrone.
  String get label => NumberFormat.simpleCurrency(
        locale: 'fr_FR',
        name: currency.toUpperCase(),
      ).format(amount / 100);
}

/// Parle aux fonctions `/api` déployées à côté de l'app sur Vercel.
///
/// Aucune clé Stripe ne vit ici : le navigateur ne fait qu'ouvrir une page de
/// paiement hébergée par Stripe et demander, ensuite, si l'abonnement existe.
class StripeBillingService {
  static const String _kDeviceId = 'billing_device_id';

  Box get _box => Hive.box(AppConstants.settingsBox);

  /// Base des appels. Sur le web, l'API est servie par le même déploiement
  /// Vercel que l'app : l'origine courante suffit, et ça marche aussi sur les
  /// déploiements de prévisualisation.
  static String get baseUrl {
    if (AppConstants.billingUrl.isNotEmpty) return AppConstants.billingUrl;
    if (kIsWeb) return Uri.base.origin;
    return '';
  }

  static bool get isConfigured => baseUrl.isNotEmpty;

  /// Rattache l'abonnement à ce navigateur.
  ///
  /// L'app n'a pas de comptes utilisateurs : cet identifiant est donc la seule
  /// chose qui relie un paiement à celui qui l'a fait. Il est tiré une fois et
  /// gardé — l'effacer (vider les données du site) fait perdre l'accès, ce que
  /// l'écran Premium explique.
  String get deviceId {
    final existing = _box.get(_kDeviceId);
    if (existing is String && existing.length == 36) return existing;

    final generated = const Uuid().v4();
    _box.put(_kDeviceId, generated);
    return generated;
  }

  /// Reprend l'abonnement d'un autre navigateur en adoptant son code.
  ///
  /// Le code EST le secret qui donne l'accès : on le stocke tel quel, et
  /// c'est Stripe qui dira ensuite s'il correspond à un abonnement.
  void adoptDeviceId(String code) => _box.put(_kDeviceId, code);

  /// Crée une session de paiement et renvoie l'URL Stripe où envoyer
  /// l'utilisateur. `null` si le serveur n'a pas pu la créer.
  Future<String?> startCheckout(PremiumPlan plan) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/checkout'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'plan': plan.apiName, 'deviceId': deviceId}),
          )
          .timeout(AppConstants.billingTimeout);

      if (response.statusCode != 200) {
        debugPrint('checkout ${response.statusCode}: ${response.body}');
        return null;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final url = body['url'];
      return url is String && url.isNotEmpty ? url : null;
    } catch (e) {
      debugPrint('startCheckout: $e');
      return null;
    }
  }

  /// Demande à Stripe si cet appareil a un abonnement.
  ///
  /// [sessionId] n'est passé qu'au retour immédiat du paiement : l'index de
  /// recherche de Stripe met jusqu'à une minute à voir un abonnement neuf,
  /// alors que la session, elle, est lisible tout de suite.
  Future<StripeEntitlement> fetchEntitlement({String? sessionId}) async {
    final query = <String, String>{
      'device': deviceId,
      if (sessionId != null && sessionId.isNotEmpty) 'session': sessionId,
    };

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/entitlement')
              .replace(queryParameters: query))
          .timeout(AppConstants.billingTimeout);

      if (response.statusCode != 200) {
        debugPrint('entitlement ${response.statusCode}: ${response.body}');
        // Une panne du serveur ne veut pas dire « pas d'abonnement ».
        return StripeEntitlement.unknown;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['active'] != true) return StripeEntitlement.inactive;

      return StripeEntitlement(
        StripeLookup.active,
        plan: PremiumPlan.fromApiName(body['plan'] as String?),
        currentPeriodEnd: DateTime.tryParse(
          body['currentPeriodEnd'] as String? ?? '',
        ),
      );
    } catch (e) {
      debugPrint('fetchEntitlement: $e');
      return StripeEntitlement.unknown;
    }
  }

  /// Ouvre le portail Stripe où l'utilisateur gère sa carte et résilie.
  /// Renvoie l'URL, ou `null` si aucun abonnement n'est rattaché à ce code.
  Future<String?> openPortal() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/portal'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'deviceId': deviceId}),
          )
          .timeout(AppConstants.billingTimeout);

      if (response.statusCode != 200) {
        debugPrint('portal ${response.statusCode}: ${response.body}');
        return null;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final url = body['url'];
      return url is String && url.isNotEmpty ? url : null;
    } catch (e) {
      debugPrint('openPortal: $e');
      return null;
    }
  }

  /// Les prix réellement facturés.
  ///
  /// `null` quand le serveur n'a pas répondu — ce n'est pas la même chose
  /// qu'une liste vide : dans un cas les fonctions ne sont pas déployées ou
  /// sont en panne, dans l'autre elles répondent mais aucun tarif n'est
  /// configuré. Les deux empêchent de payer, et l'app le dit plutôt que
  /// d'afficher un bouton qui échouera.
  Future<Map<PremiumPlan, StripePrice>?> fetchPrices() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/prices'))
          .timeout(AppConstants.billingTimeout);
      if (response.statusCode != 200) {
        debugPrint('prices ${response.statusCode}: ${response.body}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = body['prices'];
      if (raw is! Map) return null;

      final prices = <PremiumPlan, StripePrice>{};
      for (final entry in raw.entries) {
        final plan = PremiumPlan.fromApiName(entry.key as String?);
        final value = entry.value;
        if (plan == null || value is! Map) continue;

        final amount = value['amount'];
        final currency = value['currency'];
        if (amount is! int || currency is! String) continue;

        prices[plan] = StripePrice(amount: amount, currency: currency);
      }
      return prices;
    } catch (e) {
      debugPrint('fetchPrices: $e');
      return null;
    }
  }

  /// L'identifiant de session que Stripe ajoute à l'URL de retour, s'il y en
  /// a un. C'est ce qui permet de constater l'abonnement dès le retour.
  static String? get checkoutSessionFromUrl {
    if (!kIsWeb) return null;
    final id = Uri.base.queryParameters['session_id'];
    return (id != null && id.startsWith('cs_')) ? id : null;
  }
}
