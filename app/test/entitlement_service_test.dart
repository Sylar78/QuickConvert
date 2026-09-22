import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quick_convert/core/constants.dart';
import 'package:quick_convert/services/entitlement_service.dart';

/// L'abonnement est la seule chose dans cette app dont une perte coûte de
/// l'argent à l'utilisateur. Ces tests couvrent ce qui doit survivre au
/// redémarrage, et ce qui ne doit surtout pas être retiré par erreur.
void main() {
  late Directory tempDir;
  late EntitlementService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quickconvert_test');
    Hive.init(tempDir.path);
    await Hive.openBox(AppConstants.settingsBox);
    service = EntitlementService();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('sans achat, il n\'y a pas d\'abonnement', () {
    expect(service.read().isActive, isFalse);
  });

  test('un achat accordé est relu après redémarrage', () async {
    await service.grant(
      productId: AppConstants.premiumYearlyId,
      source: EntitlementSource.playStore,
    );

    // Ferme et rouvre la boîte : c'est ce que fait un redémarrage de l'app.
    await Hive.close();
    Hive.init(tempDir.path);
    await Hive.openBox(AppConstants.settingsBox);

    final entitlement = EntitlementService().read();
    expect(entitlement.isActive, isTrue);
    expect(entitlement.productId, AppConstants.premiumYearlyId);
    expect(entitlement.source, EntitlementSource.playStore);
    expect(entitlement.planLabel, 'Abonnement annuel');
  });

  test('un abonnement du store n\'a pas de date de fin locale', () async {
    // Le client ne connaît pas la date de renouvellement sans validation
    // serveur : inventer une échéance couperait l'accès d'un abonné à jour.
    await service.grant(
      productId: AppConstants.premiumMonthlyId,
      source: EntitlementSource.playStore,
    );
    expect(service.read().expiresAt, isNull);
    expect(service.read().isExpired, isFalse);
  });

  test('une activation de développement expire à l\'échéance', () async {
    await service.grant(
      productId: AppConstants.premiumMonthlyId,
      source: EntitlementSource.debug,
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    expect(service.read().isActive, isFalse);
  });

  test('une activation de développement encore valide donne l\'accès', () async {
    await service.grant(
      productId: AppConstants.premiumMonthlyId,
      source: EntitlementSource.debug,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
    expect(service.read().isActive, isTrue);
  });

  test('revoke retire l\'accès et ne laisse rien derrière', () async {
    await service.grant(
      productId: AppConstants.premiumYearlyId,
      source: EntitlementSource.playStore,
    );
    await service.revoke();

    final entitlement = service.read();
    expect(entitlement.isActive, isFalse);
    expect(entitlement.productId, isNull);
    expect(entitlement.source, isNull);
  });

  test('touch redate la vérification sans toucher au reste', () async {
    await service.grant(
      productId: AppConstants.premiumYearlyId,
      source: EntitlementSource.playStore,
    );
    final before = service.read().verifiedAt!;

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service.touch();

    final after = service.read();
    expect(after.verifiedAt!.isAfter(before), isTrue);
    expect(after.productId, AppConstants.premiumYearlyId);
    expect(after.isActive, isTrue);
  });

  test('touch sur un compte sans abonnement n\'en crée pas un', () async {
    await service.touch();
    expect(service.read().isActive, isFalse);
  });
}
