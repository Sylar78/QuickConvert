import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/source_file.dart';

/// Les fichiers envoyés à QuickConvert par une autre app : « Partager » sur
/// Android (galerie, Fichiers, WhatsApp…), « Ouvrir avec » / « Partager »
/// depuis Fichiers sur iOS.
///
/// Le système d'exploitation les remet au code natif (`MainActivity.kt`,
/// `AppDelegate.swift`), qui les copie dans le cache de l'app puis prévient
/// ici. [incoming] porte la dernière livraison jusqu'à ce que l'écran de
/// conversion la prenne.
class SharedFilesService {
  static final SharedFilesService _instance = SharedFilesService._internal();
  factory SharedFilesService() => _instance;
  SharedFilesService._internal();

  static const _channel = MethodChannel('fr.quickconvert.app/partage');

  /// Fichiers reçus et pas encore pris par l'écran de conversion.
  final ValueNotifier<List<SourceFile>?> incoming = ValueNotifier(null);

  bool _started = false;

  /// Branche l'écoute et relève ce qui a ouvert l'app. Sans effet sur le web,
  /// où le glisser-déposer et le sélecteur de fichiers jouent ce rôle.
  void start() {
    if (_started || kIsWeb) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedFilesAvailable') await _take();
    });
    _take();
  }

  Future<void> _take() async {
    try {
      final raw = await _channel.invokeListMethod<Map>('takeSharedFiles');
      final files = [
        for (final f in raw ?? const <Map>[])
          if (f['path'] is String && f['name'] is String)
            SourceFile(
              name: f['name'] as String,
              path: f['path'] as String,
              sizeBytes: (f['size'] as num?)?.toInt() ?? 0,
            ),
      ];
      if (files.isNotEmpty) incoming.value = files;
    } on MissingPluginException {
      // Plateforme sans partage branché (bureau) : rien à recevoir.
    } catch (e) {
      debugPrint('Shared files error: $e');
    }
  }

  /// Rend les fichiers reçus et vide la file.
  List<SourceFile>? consume() {
    final files = incoming.value;
    incoming.value = null;
    return files;
  }
}
