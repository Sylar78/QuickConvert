import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quick_convert/core/constants.dart';
import 'package:quick_convert/models/models.dart';
import 'package:quick_convert/services/bonus_service.dart';
import 'package:quick_convert/services/review_service.dart';

void main() {
  late Directory tempDir;
  final bonus = BonusService();
  final today = DateTime(2026, 10, 4, 15);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quickconvert_bonus');
    Hive.init(tempDir.path);
    await Hive.openBox(AppConstants.settingsBox);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('vidéos contre conversions', () {
    test('sans vidéo, pas de bonus', () {
      expect(bonus.bonusToday(today), 0);
      expect(bonus.canWatchMore(today), isTrue);
    });

    test('chaque vidéo ajoute ses conversions, jusqu\'au plafond du jour', () async {
      for (var i = 0; i < AppConstants.rewardedAdsPerDay + 2; i++) {
        await bonus.grant(today);
      }
      expect(bonus.adsWatchedToday(today), AppConstants.rewardedAdsPerDay);
      expect(
        bonus.bonusToday(today),
        AppConstants.rewardedAdsPerDay * AppConstants.rewardedBonusConversions,
      );
      expect(bonus.canWatchMore(today), isFalse);
    });

    test('le bonus ne vaut que pour la journée', () async {
      await bonus.grant(today);
      final tomorrow = today.add(const Duration(days: 1));
      expect(bonus.bonusToday(tomorrow), 0);
      expect(bonus.canWatchMore(tomorrow), isTrue);
    });

    test('le bonus s\'ajoute au quota affiché et appliqué', () {
      final user = UserModel(
        createdAt: today,
        conversionsToday: AppConstants.freeConversionsPerDay,
        bonusConversions: 2,
      );
      expect(user.dailyLimit, AppConstants.freeConversionsPerDay + 2);
      expect(user.canConvert, isTrue);
      expect(user.remainingConversions, 2);
    });
  });

  group('demande de note', () {
    test('pas avant la troisième conversion réussie', () {
      expect(ReviewService.shouldAsk(2, 0), isFalse);
      expect(ReviewService.shouldAsk(3, 0), isTrue);
    });

    test('une seule fois par palier', () {
      expect(ReviewService.shouldAsk(4, 3), isFalse);
      expect(ReviewService.shouldAsk(15, 3), isTrue);
      expect(ReviewService.shouldAsk(40, 15), isFalse);
      expect(ReviewService.shouldAsk(50, 15), isTrue);
      expect(ReviewService.shouldAsk(500, 50), isFalse);
    });
  });

  test('DOC → PDF n\'est pas proposé sans service cloud', () {
    expect(AppConstants.hasBackend, isFalse);
    expect(ConversionCatalog.fromFormat(FileFormat.doc), isEmpty);
    expect(ConversionCatalog.inputExtensions, isNot(contains('docx')));
    // L'historique, lui, sait toujours afficher une conversion passée.
    expect(ConversionType.docToPdf.label, 'DOC → PDF');
  });
}
