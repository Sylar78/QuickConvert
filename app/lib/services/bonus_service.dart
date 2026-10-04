import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants.dart';

/// Les conversions gratuites gagnées aujourd'hui en regardant une vidéo.
///
/// Persistées dans la boîte `settings` avec leur date : elles valent pour la
/// journée, comme le quota qu'elles complètent, et repartent à zéro le
/// lendemain sans rien avoir à effacer.
class BonusService {
  static final BonusService _instance = BonusService._internal();
  factory BonusService() => _instance;
  BonusService._internal();

  static const _key = 'rewarded_ads_today';

  Box get _box => Hive.box(AppConstants.settingsBox);

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Vidéos regardées aujourd'hui.
  int adsWatchedToday([DateTime? now]) {
    final stored = _box.get(_key);
    if (stored is! Map) return 0;
    if (stored['day'] != _day(now ?? DateTime.now())) return 0;
    return (stored['ads'] as int?) ?? 0;
  }

  /// Conversions ajoutées au quota du jour.
  int bonusToday([DateTime? now]) =>
      adsWatchedToday(now) * AppConstants.rewardedBonusConversions;

  bool canWatchMore([DateTime? now]) =>
      adsWatchedToday(now) < AppConstants.rewardedAdsPerDay;

  /// À appeler quand la vidéo a été regardée jusqu'à la récompense.
  Future<void> grant([DateTime? now]) async {
    final day = _day(now ?? DateTime.now());
    if (!canWatchMore(now)) return;
    await _box.put(_key, {'day': day, 'ads': adsWatchedToday(now) + 1});
  }
}
