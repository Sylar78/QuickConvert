import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'models/models.dart';
import 'services/services.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientation portrait uniquement ──────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Status bar transparente ────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Hive (base de données locale) ─────────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(ConversionRecordAdapter());
  await Hive.openBox<ConversionRecord>(AppConstants.historyBox);
  await Hive.openBox(AppConstants.settingsBox);

  // ── Supabase ───────────────────────────────────────────────────────────────
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    debug: false,
  );

  // ── AdMob ─────────────────────────────────────────────────────────────────
  await AdmobService().initialize();

  // ── Lancement ─────────────────────────────────────────────────────────────
  runApp(const QuickConvertApp());
}
