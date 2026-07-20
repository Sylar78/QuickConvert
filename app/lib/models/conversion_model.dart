import 'package:hive/hive.dart';

part 'conversion_model.g.dart';

enum ConversionType {
  pdfToJpg,
  jpgToPdf,
  pngToJpg,
  jpgToPng,
  docToPdf,
  pngToPdf,
  svgToPng,
}

extension ConversionTypeExtension on ConversionType {
  String get label {
    switch (this) {
      case ConversionType.pdfToJpg:
        return 'PDF → JPG';
      case ConversionType.jpgToPdf:
        return 'JPG → PDF';
      case ConversionType.pngToJpg:
        return 'PNG → JPG';
      case ConversionType.jpgToPng:
        return 'JPG → PNG';
      case ConversionType.docToPdf:
        return 'DOC → PDF';
      case ConversionType.pngToPdf:
        return 'PNG → PDF';
      case ConversionType.svgToPng:
        return 'SVG → PNG';
    }
  }

  String get inputFormat {
    switch (this) {
      case ConversionType.pdfToJpg:
        return 'PDF';
      case ConversionType.jpgToPdf:
        return 'JPG';
      case ConversionType.pngToJpg:
        return 'PNG';
      case ConversionType.jpgToPng:
        return 'JPG';
      case ConversionType.docToPdf:
        return 'DOC';
      case ConversionType.pngToPdf:
        return 'PNG';
      case ConversionType.svgToPng:
        return 'SVG';
    }
  }

  String get outputFormat {
    switch (this) {
      case ConversionType.pdfToJpg:
        return 'JPG';
      case ConversionType.jpgToPdf:
        return 'PDF';
      case ConversionType.pngToJpg:
        return 'JPG';
      case ConversionType.jpgToPng:
        return 'PNG';
      case ConversionType.docToPdf:
        return 'PDF';
      case ConversionType.pngToPdf:
        return 'PDF';
      case ConversionType.svgToPng:
        return 'PNG';
    }
  }

  String get description {
    switch (this) {
      case ConversionType.pdfToJpg:
        return 'Extraire les pages de ton PDF en images';
      case ConversionType.jpgToPdf:
        return 'Combiner tes photos en un seul PDF';
      case ConversionType.pngToJpg:
        return 'Convertir et compresser tes PNG';
      case ConversionType.jpgToPng:
        return 'Convertir tes JPG en PNG sans perte';
      case ConversionType.docToPdf:
        return 'Transformer ton document en PDF';
      case ConversionType.pngToPdf:
        return 'Créer un PDF depuis tes images PNG';
      case ConversionType.svgToPng:
        return 'Convertir tes SVG en images PNG';
    }
  }
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

  ConversionType get conversionType =>
      ConversionType.values[int.tryParse(typeIndex) ?? 0];

  String get formattedSize {
    final bytes = outputFileSizeBytes ?? inputFileSizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
