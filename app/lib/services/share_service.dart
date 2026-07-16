import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  /// Partager un fichier converti
  Future<void> shareFile(String filePath, {String? subject}) async {
    final file = XFile(filePath);
    final fileName = p.basename(filePath);

    await Share.shareXFiles(
      [file],
      subject: subject ?? 'Fichier converti par QuickConvert',
      text: 'Voici ton fichier $fileName converti avec QuickConvert 🚀',
    );
  }

  /// Partager plusieurs fichiers
  Future<void> shareFiles(List<String> filePaths, {String? subject}) async {
    final files = filePaths.map((path) => XFile(path)).toList();

    await Share.shareXFiles(
      files,
      subject: subject ?? 'Fichiers convertis par QuickConvert',
      text: 'Voici tes fichiers convertis avec QuickConvert 🚀',
    );
  }

  /// Partager un lien (mini-site)
  Future<void> shareAppLink() async {
    await Share.share(
      'Convertis tes fichiers instantanément avec QuickConvert 🚀\n'
      'iOS: https://apps.apple.com/app/quickconvert\n'
      'Android: https://play.google.com/store/apps/details?id=com.quickconvert',
      subject: 'QuickConvert — Conversion de fichiers',
    );
  }
}
