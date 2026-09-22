import 'dart:typed_data';

/// Un fichier choisi par l'utilisateur, quelle que soit la plateforme.
///
/// Sur mobile on travaille avec un chemin, sur le web avec des octets en
/// mémoire. Avant, les deux vivaient dans deux champs séparés de l'écran de
/// conversion, qu'il fallait penser à garder synchronisés — retirer un fichier
/// n'en retirait qu'une moitié. Ici les deux cas sont le même objet.
class SourceFile {
  /// Nom affiché, avec son extension.
  final String name;

  /// Chemin sur disque. `null` sur le web.
  final String? path;

  /// Contenu en mémoire. `null` sur mobile, où on lit depuis [path].
  final Uint8List? bytes;

  /// Taille en octets, connue au moment de la sélection.
  final int sizeBytes;

  const SourceFile({
    required this.name,
    required this.sizeBytes,
    this.path,
    this.bytes,
  });

  bool get hasBytes => bytes != null;
  bool get hasPath => path != null;
}
