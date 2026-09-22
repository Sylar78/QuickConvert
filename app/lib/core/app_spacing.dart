/// Échelle d'espacement. Une seule suite de valeurs pour toute l'app, au lieu
/// de nombres choisis écran par écran.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;

  /// Marge latérale du contenu d'un écran.
  static const double gutter = 20;
}

/// Rayons de bordure. Trois niveaux : petit pour les puces, moyen pour les
/// cartes, grand pour les feuilles et les zones de dépôt.
class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;
}

/// Durées d'animation.
class AppDuration {
  const AppDuration._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 500);
}

/// Seuils de mise en page.
class AppBreakpoints {
  const AppBreakpoints._();

  /// Largeur maximale d'une colonne de contenu. Au-delà, on centre plutôt
  /// que d'étirer — c'est ce qui manquait sur le web en plein écran.
  static const double content = 620;

  /// À partir d'ici, la navigation passe de la barre du bas à un rail latéral.
  static const double expanded = 760;
}
