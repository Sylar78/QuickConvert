// ============================================================
// QuickConvert — Constants
// ============================================================

class AppConstants {
  const AppConstants._();

  // App info
  static const String appName = 'QuickConvert';
  static const String appTagline = 'Convertis tes fichiers instantanément';
  static const String siteUrl = 'https://quickconvert.app';

  // Supabase
  static const String supabaseUrl = 'https://buuwdmnmjmbaipvxmmoo.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_7qF9ev0PiiNnVJkjgjrwew_JDGv39Px';

  /// Comptes et synchronisation. Supabase est commenté dans `main.dart` et
  /// `auth_provider.dart` ; tant que c'est le cas, l'interface ne propose pas
  /// de se connecter plutôt que d'ouvrir un écran qui refuse.
  static const bool authEnabled = false;

  /// URL du service de conversion cloud, fournie au build :
  ///   flutter build web --dart-define=QC_BACKEND_URL=https://api.example.com
  ///
  /// Vide par défaut : les conversions qui en dépendent (DOC → PDF) annoncent
  /// alors clairement qu'elles sont indisponibles, au lieu d'appeler
  /// `localhost` depuis le téléphone de l'utilisateur.
  static const String backendUrl =
      String.fromEnvironment('QC_BACKEND_URL', defaultValue: '');

  static bool get hasBackend => backendUrl.isNotEmpty;

  // AdMob IDs (test IDs by default — replace with real ones in production)
  static const String admobBannerIdAndroid = 'ca-app-pub-6336563192834287~9992114041';
  static const String admobInterstitialIdAndroid = 'ca-app-pub-6336563192834287/6052869030';
  static const String admobBannerIdIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String admobInterstitialIdIos = 'ca-app-pub-3940256099942544/4411468910';

  // In-App Purchase
  static const String premiumMonthlyId = 'quickconvert_premium_monthly';
  static const String premiumYearlyId = 'quickconvert_premium_yearly';

  /// Prix affichés quand le store n'a pas encore répondu. Dès que
  /// `in_app_purchase` a chargé les produits, c'est son prix localisé qui
  /// s'affiche — c'est ce que demandent les règles du Play Store.
  static const String fallbackMonthlyPrice = '4,99 €';
  static const String fallbackYearlyPrice = '24,99 €';

  /// Temps laissé au store pour livrer ses achats restaurés avant de conclure
  /// qu'il n'en a pas. Voir `SubscriptionProvider._runRestore` : trop court, on
  /// couperait le Premium d'un abonné ; trop long, la restauration manuelle
  /// paraît figée.
  static const Duration restoreSettleDelay = Duration(seconds: 6);

  /// Page de gestion des abonnements de Google Play. Le Play Store exige que
  /// l'app y donne accès depuis l'écran de l'abonnement.
  static const String playSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';

  /// Équivalent côté Apple.
  static const String appStoreSubscriptionsUrl =
      'https://apps.apple.com/account/subscriptions';

  // Free tier limits
  static const int freeConversionsPerDay = 5;

  // Hive boxes
  static const String historyBox = 'conversion_history';
  static const String settingsBox = 'settings';
  static const String userBox = 'user';

  /// Nombre de conversions gardées dans l'historique local.
  static const int historyLimit = 50;

  // Max file size (bytes) — 50 MB
  static const int maxFileSizeBytes = 50 * 1024 * 1024;
  static const String maxFileSizeLabel = '50 Mo';
}
