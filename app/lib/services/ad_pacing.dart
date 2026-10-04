/// Décide quand une conversion gratuite déclenche une publicité plein écran.
///
/// Une annonce à chaque conversion ferait fuir les utilisateurs, et AdMob
/// pénalise les interstitiels trop rapprochés. La règle : la première
/// conversion de la session n'en montre pas, puis une conversion sur
/// [every], jamais deux annonces à moins de [minInterval] d'écart. Une
/// conversion écartée par l'intervalle reste « due » : la suivante la montre.
///
/// Pur et sans dépendance au SDK publicitaire, pour être testé.
class AdPacing {
  AdPacing({
    this.every = 2,
    this.minInterval = const Duration(seconds: 90),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int every;
  final Duration minInterval;
  final DateTime Function() _clock;

  int _sinceLastAd = 0;
  DateTime? _lastShownAt;

  /// À appeler une fois par conversion lancée. Vrai si celle-ci doit
  /// montrer une annonce.
  bool registerConversion() {
    _sinceLastAd++;
    if (_sinceLastAd < every) return false;
    final last = _lastShownAt;
    return last == null || _clock().difference(last) >= minInterval;
  }

  /// À appeler seulement si l'annonce s'est vraiment affichée : une annonce
  /// qui n'a pas chargé ne doit pas repousser la suivante.
  void markShown() {
    _sinceLastAd = 0;
    _lastShownAt = _clock();
  }
}
