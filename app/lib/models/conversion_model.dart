import 'package:hive/hive.dart';

part 'conversion_model.g.dart';

/// Les conversions supportées.
///
/// ATTENTION : l'index de chaque valeur est stocké dans l'historique Hive
/// (`ConversionRecord.typeIndex`). N'ajoute qu'à la fin, ne réordonne jamais.
/// Les libellés et descriptions vivent dans `conversion_catalog.dart`.
enum ConversionType {
  pdfToJpg,
  jpgToPdf,
  pngToJpg,
  jpgToPng,
  docToPdf,
  pngToPdf,
  svgToPng,
}

enum ConversionStatus { pending, processing, success, error }

@HiveType(typeId: 0)
class ConversionRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String typeIndex; // ConversionType.index stored as String

  @HiveField(2)
  final String inputFileName;

  @HiveField(3)
  final String? outputFilePath;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final int inputFileSizeBytes;

  @HiveField(6)
  final int? outputFileSizeBytes;

  @HiveField(7)
  final bool isSuccess;

  @HiveField(8)
  final String? errorMessage;

  ConversionRecord({
    required this.id,
    required this.typeIndex,
    required this.inputFileName,
    this.outputFilePath,
    required this.createdAt,
    required this.inputFileSizeBytes,
    this.outputFileSizeBytes,
    required this.isSuccess,
    this.errorMessage,
  });

  ConversionType get conversionType {
    final index = int.tryParse(typeIndex) ?? 0;
    if (index < 0 || index >= ConversionType.values.length) {
      return ConversionType.pdfToJpg;
    }
    return ConversionType.values[index];
  }

  String get formattedSize => formatBytes(outputFileSizeBytes ?? inputFileSizeBytes);
}

/// Taille lisible d'un fichier, en unités françaises (1,4 Mo).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} Ko';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}
