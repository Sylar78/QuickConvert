// ============================================================
// QuickConvert — Constants
// ============================================================

class AppConstants {
  // App info
  static const String appName = 'QuickConvert';
  static const String appTagline = 'Convertis tes fichiers instantanément';

  // Supabase
  static const String supabaseUrl = 'https://buuwdmnmjmbaipvxmmoo.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_7qF9ev0PiiNnVJkjgjrwew_JDGv39Px';

  // Backend API
  static const String backendUrl = 'http://localhost:3000';

  // AdMob IDs (test IDs by default — replace with real ones in production)
  static const String admobBannerIdAndroid = 'ca-app-pub-6336563192834287~9992114041';
  static const String admobInterstitialIdAndroid = 'ca-app-pub-6336563192834287/6052869030';
  static const String admobBannerIdIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String admobInterstitialIdIos = 'ca-app-pub-3940256099942544/4411468910';

  // In-App Purchase
  static const String premiumMonthlyId = 'quickconvert_premium_monthly';
  static const String premiumYearlyId = 'quickconvert_premium_yearly';

  // Free tier limits
  static const int freeConversionsPerDay = 5;

  // Hive boxes
  static const String historyBox = 'conversion_history';
  static const String settingsBox = 'settings';
  static const String userBox = 'user';

  // Supported formats
  static const List<String> pdfExtensions = ['pdf'];
  static const List<String> imageExtensions = ['jpg', 'jpeg', 'png'];
  static const List<String> docExtensions = ['doc', 'docx'];

  // Max file size (bytes) — 50 MB
  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  // Animation durations
  static const Duration shortAnim = Duration(milliseconds: 200);
  static const Duration mediumAnim = Duration(milliseconds: 400);
  static const Duration longAnim = Duration(milliseconds: 700);
}
