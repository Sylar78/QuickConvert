import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_review/in_app_review.dart';

import '../core/constants.dart';

/// Demande une note sur le store, au bon moment et rarement.
///
/// Le moment : à la fermeture du résultat d'une conversion réussie, quand
/// l'utilisateur vient d'obtenir ce qu'il voulait — jamais pendant une
/// publicité ni au milieu d'un geste. La fréquence : à la 3e, la 15e puis la
/// 50e conversion réussie, pas plus. Apple n'affiche de toute façon la
/// fenêtre que trois fois par an et Google la limite aussi ; ces paliers
/// évitent de gaspiller ces occasions sur un utilisateur qui découvre l'app.
class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  static const _countKey = 'successful_conversions';
  static const _askedKey = 'review_asked_at';

  /// Paliers de conversions réussies auxquels la note est demandée.
  static const List<int> milestones = [3, 15, 50];

  Box get _box => Hive.box(AppConstants.settingsBox);

  /// Vrai si, à [count] conversions réussies et une dernière demande faite
  /// à [lastAskedAt] conversions, il faut demander une note.
  static bool shouldAsk(int count, int lastAskedAt) =>
      milestones.any((m) => count >= m && lastAskedAt < m);

  /// À appeler après chaque conversion réussie.
  Future<void> recordSuccess() async {
    final count = (_box.get(_countKey) as int? ?? 0) + 1;
    await _box.put(_countKey, count);
  }

  /// À appeler quand le résultat d'une conversion se ferme.
  Future<void> maybeAsk() async {
    if (kIsWeb) return;
    final count = _box.get(_countKey) as int? ?? 0;
    final asked = _box.get(_askedKey) as int? ?? 0;
    if (!shouldAsk(count, asked)) return;

    // Noté avant la demande : une fenêtre qui échoue ne doit pas revenir à
    // chaque conversion.
    await _box.put(_askedKey, count);
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (e) {
      debugPrint('Review request error: $e');
    }
  }
}
