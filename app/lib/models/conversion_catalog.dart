import '../core/constants.dart';
import 'conversion_model.dart';
import 'file_format.dart';

/// Une conversion possible : un format d'entrée, un format de sortie, et le
/// [ConversionType] correspondant.
///
/// [ConversionType] reste la clé de l'historique (son index est stocké dans
/// Hive), donc son ordre ne doit jamais changer. Tout le reste — libellés,
/// descriptions, extensions acceptées, capacités — se déclare ici, en un seul
/// endroit, au lieu d'être réparti dans une demi-douzaine de `switch`.
class ConversionRoute {
  final FileFormat from;
  final FileFormat to;
  final ConversionType type;
  final String description;

  /// La conversion accepte plusieurs fichiers d'entrée pour une seule sortie.
  final bool supportsBatch;

  /// La conversion a besoin du service cloud et échoue sans lui.
  final bool requiresBackend;

  const ConversionRoute({
    required this.from,
    required this.to,
    required this.type,
    required this.description,
    this.supportsBatch = false,
    this.requiresBackend = false,
  });

  String get label => '${from.label} → ${to.label}';
}

/// Le catalogue des conversions. Ajouter un format se fait ici, plus dans les
/// écrans : une entrée dans [ConversionType], une ligne dans [routes].
class ConversionCatalog {
  const ConversionCatalog._();

  static const List<ConversionRoute> routes = [
    ConversionRoute(
      from: FileFormat.pdf,
      to: FileFormat.jpg,
      type: ConversionType.pdfToJpg,
      description: 'Une image par page du document',
    ),
    ConversionRoute(
      from: FileFormat.jpg,
      to: FileFormat.pdf,
      type: ConversionType.jpgToPdf,
      description: 'Tes photos regroupées dans un seul PDF',
      supportsBatch: true,
    ),
    ConversionRoute(
      from: FileFormat.png,
      to: FileFormat.jpg,
      type: ConversionType.pngToJpg,
      description: 'Plus léger, à qualité équivalente',
    ),
    ConversionRoute(
      from: FileFormat.jpg,
      to: FileFormat.png,
      type: ConversionType.jpgToPng,
      description: 'Sans nouvelle perte de qualité',
    ),
    ConversionRoute(
      from: FileFormat.doc,
      to: FileFormat.pdf,
      type: ConversionType.docToPdf,
      description: 'Mise en page conservée',
      requiresBackend: true,
    ),
    ConversionRoute(
      from: FileFormat.png,
      to: FileFormat.pdf,
      type: ConversionType.pngToPdf,
      description: 'Tes images regroupées dans un seul PDF',
      supportsBatch: true,
    ),
    ConversionRoute(
      from: FileFormat.svg,
      to: FileFormat.png,
      type: ConversionType.svgToPng,
      description: 'Ton vectoriel rendu en 1024 px de large',
    ),
  ];

  static final Map<ConversionType, ConversionRoute> _byType = {
    for (final route in routes) route.type: route,
  };

  /// La route correspondant à un [ConversionType]. Tous les types en ont une.
  static ConversionRoute of(ConversionType type) => _byType[type]!;

  /// Les conversions proposées dans ce build.
  ///
  /// Une conversion qui a besoin du service cloud n'apparaît que si son
  /// adresse a été fournie au build (`QC_BACKEND_URL`) : sinon elle était
  /// offerte puis échouait à chaque fois. [routes] garde toutes les entrées,
  /// parce que l'historique doit pouvoir afficher une conversion passée.
  static List<ConversionRoute> get available => [
        for (final route in routes)
          if (!route.requiresBackend || AppConstants.hasBackend) route,
      ];

  /// Les formats que l'app sait ouvrir, dans l'ordre du catalogue.
  static List<FileFormat> get inputFormats =>
      available.map((r) => r.from).toSet().toList();

  /// Toutes les extensions acceptées à l'import, pour le sélecteur de fichier.
  static List<String> get inputExtensions =>
      inputFormats.expand((f) => f.extensions).toSet().toList();

  /// Les conversions possibles depuis un format donné.
  static List<ConversionRoute> fromFormat(FileFormat input) =>
      available.where((r) => r.from == input).toList();

  /// La route reliant deux formats, ou `null` si la conversion n'existe pas.
  static ConversionRoute? between(FileFormat from, FileFormat to) {
    for (final route in available) {
      if (route.from == from && route.to == to) return route;
    }
    return null;
  }

  /// Le format d'un fichier, déduit de son extension.
  /// Retourne `null` pour un fichier que l'app ne sait pas ouvrir.
  static FileFormat? detect(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    final ext = fileName.substring(dot + 1).toLowerCase();
    for (final format in FileFormat.values) {
      if (format.extensions.contains(ext)) return format;
    }
    return null;
  }
}

extension ConversionTypeX on ConversionType {
  ConversionRoute get route => ConversionCatalog.of(this);
  String get label => route.label;
  String get description => route.description;
  String get inputFormat => route.from.label;
  String get outputFormat => route.to.label;
  bool get supportsBatch => route.supportsBatch;
  bool get requiresBackend => route.requiresBackend;
}
