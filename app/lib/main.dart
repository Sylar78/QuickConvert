import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // DÉSACTIVÉ
import 'core/constants.dart';
import 'models/models.dart';
import 'services/services.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientations ──────────────────────────────────────────────────────────
  // Le paysage est autorisé : la mise en page s'y adapte maintenant, avec un
  // rail latéral au lieu de la barre du bas dès que l'écran est large.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // La couleur des icônes de la barre d'état suit le thème, via
  // `AppBarTheme.systemOverlayStyle` — elle n'est plus figée en sombre ici.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // ── Hive (base de données locale) ─────────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(ConversionRecordAdapter());
  await Hive.openBox<ConversionRecord>(AppConstants.historyBox);
  await Hive.openBox(AppConstants.settingsBox);

  // ── Supabase ── DÉSACTIVÉ TEMPORAIREMENT ─────────────────────────────────
  // Voir AppConstants.authEnabled : tant que c'est false, l'interface ne
  // propose pas de créer un compte.

  // ── AdMob ─────────────────────────────────────────────────────────────────
  try {
    await AdmobService().initialize();
  } catch (e) {
    debugPrint('AdMob init error: $e');
  }

  runApp(const QuickConvertApp());
}
