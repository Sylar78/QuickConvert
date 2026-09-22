import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants.dart';

/// D'où vient l'abonnement actif.
enum EntitlementSource {
  /// Achat passé par Google Play.
  playStore,

  /// Achat passé par l'App Store d'Apple.
  appStore,

  /// Activation manuelle en mode développement. Jamais présente dans un
  /// build de production : voir `PremiumScreen`.
  debug,
}

/// L'abonnement tel qu'il est connu localement.
///
/// [expiresAt] est nulle pour un abonnement acheté sur un store : sans
/// validation côté serveur, le client ne connaît pas la date de
/// renouvellement. C'est le store qui fait foi, et la réconciliation au
/// lancement (voir `SubscriptionProvider`) est ce qui retire l'accès quand
/// l'abonnement n'est plus actif.
@immutable
class Entitlement {
  final bool isActive;
  final String? productId;
  final EntitlementSource? source;

  /// Dernière fois que le store a confirmé cet abonnement.
  final DateTime? verifiedAt;

  /// Fin de validité, quand elle est connue (activation de développement).
  final DateTime? expiresAt;

  const Entitlement({
    required this.isActive,
    this.productId,
    this.source,
    this.verifiedAt,
    this.expiresAt,
  });

  static const Entitlement none = Entitlement(isActive: false);

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Le libellé de l'offre, pour l'écran Premium.
  String get planLabel {
    if (productId == AppConstants.premiumYearlyId) return 'Abonnement annuel';
    if (productId == AppConstants.premiumMonthlyId) return 'Abonnement mensuel';
    return 'Abonnement Premium';
  }
}

/// Lit et écrit l'abonnement dans le stockage local.
///
/// C'est la seule source de vérité pour « cet utilisateur est-il Premium ».
/// Avant, l'activation ne vivait qu'en mémoire dans `AuthProvider` : un achat
/// réussi était perdu au redémarrage de l'app, et l'utilisateur repassait
/// gratuit après avoir payé.
class EntitlementService {
  static const String _kActive = 'premium_active';
  static const String _kProductId = 'premium_product_id';
  static const String _kSource = 'premium_source';
  static const String _kVerifiedAt = 'premium_verified_at';
  static const String _kExpiresAt = 'premium_expires_at';

  Box get _box => Hive.box(AppConstants.settingsBox);

  /// L'abonnement courant, expiration déjà prise en compte.
  Entitlement read() {
    if (_box.get(_kActive) != true) return Entitlement.none;

    final entitlement = Entitlement(
      isActive: true,
      productId: _box.get(_kProductId) as String?,
      source: _sourceFromName(_box.get(_kSource) as String?),
      verifiedAt: _dateFrom(_box.get(_kVerifiedAt)),
      expiresAt: _dateFrom(_box.get(_kExpiresAt)),
    );

    if (entitlement.isExpired) return Entitlement.none;
    return entitlement;
  }

  /// Accorde l'accès Premium et le persiste.
  ///
  /// Appelée après qu'un store a confirmé un achat, ou l'a renvoyé lors
  /// d'une restauration.
  Future<Entitlement> grant({
    required String productId,
    required EntitlementSource source,
    DateTime? expiresAt,
  }) async {
    await _box.putAll(<String, dynamic>{
      _kActive: true,
      _kProductId: productId,
      _kSource: source.name,
      _kVerifiedAt: DateTime.now().toIso8601String(),
      _kExpiresAt: expiresAt?.toIso8601String(),
    });
    return read();
  }

  /// Note que le store vient de reconfirmer l'abonnement, sans rien changer
  /// d'autre. Sert à dater la dernière vérification réussie.
  Future<void> touch() async {
    if (_box.get(_kActive) != true) return;
    await _box.put(_kVerifiedAt, DateTime.now().toIso8601String());
  }

  /// Retire l'accès Premium.
  ///
  /// N'est appelée que lorsque le store a répondu et n'a pas renvoyé
  /// l'abonnement : jamais sur un simple échec réseau.
  Future<void> revoke() async {
    await _box.deleteAll(<String>[
      _kActive,
      _kProductId,
      _kSource,
      _kVerifiedAt,
      _kExpiresAt,
    ]);
  }

  static EntitlementSource? _sourceFromName(String? name) {
    for (final source in EntitlementSource.values) {
      if (source.name == name) return source;
    }
    return null;
  }

  static DateTime? _dateFrom(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }
}
