import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import 'svg_to_png.dart' as svg_converter;

/// Erreur de conversion dont le message est destiné à l'utilisateur.
class ConversionException implements Exception {
  final String message;
  const ConversionException(this.message);
  @override
  String toString() => message;
}

/// Décode puis ré-encode une image, dans un seul aller-retour d'isolate.
///
/// Le découpage précédent (décoder dans un isolate, encoder sur le thread UI)
/// avait deux défauts : l'encodage, qui est la partie lente, bloquait l'app, et
/// l'image décodée devait repasser la frontière d'isolate — sur une photo de
/// 12 Mpx cela représente une cinquantaine de Mo copiés pour rien. Ici seuls
/// les octets entrent et sortent.
Uint8List _transcodeImage((Uint8List bytes, bool toPng, int quality) request) {
  final (bytes, toPng, quality) = request;
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw const ConversionException('Ce fichier n\'est pas une image lisible.');
  }
  return toPng
      ? Uint8List.fromList(img.encodePng(image))
      : Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

class ConversionService {
  static final ConversionService _instance = ConversionService._internal();
  factory ConversionService() => _instance;
  ConversionService._internal();

  final _uuid = const Uuid();

  // ─── Répertoire de sortie ─────────────────────────────────────────────────
  Future<Directory> get _outputDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'QuickConvert', 'output'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ─── PDF → JPG ────────────────────────────────────────────────────────────
  Future<List<String>> pdfToJpg(String pdfPath) async {
    final outputPaths = <String>[];
    final outDir = await _outputDir;
    final basename = p.basenameWithoutExtension(pdfPath);

    final document = await PdfDocument.openFile(pdfPath);
    try {
      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        try {
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#ffffff',
          );
          if (pageImage == null) continue;
          final filePath = p.join(outDir.path, '${basename}_page_$i.jpg');
          await File(filePath).writeAsBytes(pageImage.bytes);
          outputPaths.add(filePath);
        } finally {
          await page.close();
        }
      }
    } finally {
      await document.close();
    }

    if (outputPaths.isEmpty) {
      throw const ConversionException('Aucune page n\'a pu être extraite de ce PDF.');
    }
    return outputPaths;
  }

  Future<List<Uint8List>> pdfToJpgBytes(Uint8List pdfBytes) async {
    final document = await PdfDocument.openData(pdfBytes);
    final results = <Uint8List>[];
    try {
      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        try {
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#ffffff',
          );
          if (pageImage != null) results.add(pageImage.bytes);
        } finally {
          await page.close();
        }
      }
    } finally {
      await document.close();
    }

    if (results.isEmpty) {
      throw const ConversionException('Aucune page n\'a pu être extraite de ce PDF.');
    }
    return results;
  }

  // ─── Images → PDF ─────────────────────────────────────────────────────────
  Future<String> imagesToPdf(List<String> imagePaths) async {
    final outDir = await _outputDir;
    final outputPath =
        p.join(outDir.path, 'converted_${_uuid.v4().substring(0, 8)}.pdf');

    final images = <Uint8List>[];
    for (final imagePath in imagePaths) {
      images.add(await File(imagePath).readAsBytes());
    }

    await File(outputPath).writeAsBytes(await imagesToPdfBytes(images));
    return outputPath;
  }

  Future<Uint8List> imagesToPdfBytes(List<Uint8List> imageBytesList) async {
    final pdf = pw.Document();
    for (final imageBytes in imageBytesList) {
      final pdfImage = pw.MemoryImage(imageBytes);
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
      ));
    }
    return Uint8List.fromList(await pdf.save());
  }

  // ─── PNG ⇄ JPG ────────────────────────────────────────────────────────────
  Future<String> pngToJpg(String pngPath, {int quality = 90}) =>
      _transcodeFile(pngPath, toPng: false, quality: quality);

  Future<String> jpgToPng(String jpgPath) => _transcodeFile(jpgPath, toPng: true);

  Future<String> _transcodeFile(String inputPath,
      {required bool toPng, int quality = 90}) async {
    final outDir = await _outputDir;
    final basename = p.basenameWithoutExtension(inputPath);
    final outputPath = p.join(outDir.path, '$basename.${toPng ? 'png' : 'jpg'}');

    final bytes = await File(inputPath).readAsBytes();
    final output = await imageFormatBytes(bytes, toPng: toPng, quality: quality);
    await File(outputPath).writeAsBytes(output);
    return outputPath;
  }

  /// Transcode une image d'un format à l'autre.
  ///
  /// Le travail part dans un isolate sur mobile et desktop. Sur le web, Flutter
  /// exécute `compute` de façon synchrone faute d'isolates : l'interface y reste
  /// bloquée pendant l'encodage, ce qu'il faudra régler avec un web worker.
  Future<Uint8List> imageFormatBytes(
    Uint8List inputBytes, {
    bool toPng = false,
    int quality = 90,
  }) {
    return compute(_transcodeImage, (inputBytes, toPng, quality));
  }

  // ─── DOC/DOCX → PDF ───────────────────────────────────────────────────────
  /// Convertit un document via le service cloud (LibreOffice).
  ///
  /// Il n'existe pas de conversion DOC → PDF locale fidèle. La version
  /// précédente fabriquait à la place un PDF d'une page expliquant la
  /// limitation, et l'enregistrait comme une conversion réussie : l'utilisateur
  /// repartait avec un fichier qui n'était pas son document. Sans backend
  /// configuré, on le dit maintenant franchement.
  Future<String> docToPdf(String docPath) async {
    final outDir = await _outputDir;
    final basename = p.basenameWithoutExtension(docPath);
    final outputPath = p.join(outDir.path, '$basename.pdf');

    final bytes = await File(docPath).readAsBytes();
    final pdfBytes = await docToPdfBytes(bytes, p.basename(docPath));

    await File(outputPath).writeAsBytes(pdfBytes);
    return outputPath;
  }

  Future<Uint8List> docToPdfBytes(Uint8List docBytes, String fileName) async {
    if (!AppConstants.hasBackend) {
      throw const ConversionException(
        'La conversion DOC → PDF passe par notre service en ligne, '
        'qui n\'est pas disponible dans cette version.',
      );
    }

    final uri = Uri.parse('${AppConstants.backendUrl}/api/convert/doc-to-pdf');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('file', docBytes, filename: fileName));

    final http.Response response;
    try {
      response = await http.Response.fromStream(await request.send());
    } catch (_) {
      throw const ConversionException(
        'Le service de conversion est injoignable. Vérifie ta connexion.',
      );
    }

    if (response.statusCode != 200) {
      throw const ConversionException(
        'Le service de conversion n\'a pas pu traiter ce document.',
      );
    }
    return response.bodyBytes;
  }

  // ─── SVG → PNG ────────────────────────────────────────────────────────────
  Future<String> svgToPng(String svgPath, {int width = 1024}) async {
    final outDir = await _outputDir;
    final basename = p.basenameWithoutExtension(svgPath);
    final outputPath = p.join(outDir.path, '$basename.png');

    final svgBytes = await File(svgPath).readAsBytes();
    final pngBytes = await svgToPngBytes(svgBytes, width: width);
    await File(outputPath).writeAsBytes(pngBytes);
    return outputPath;
  }

  Future<Uint8List> svgToPngBytes(Uint8List svgBytes, {int width = 1024}) async {
    final svgString = String.fromCharCodes(svgBytes);

    // Dimensions d'origine, lues dans le viewBox ou à défaut dans width/height,
    // pour conserver le rapport d'aspect du vectoriel.
    double svgWidth = width.toDouble();
    double svgHeight = width.toDouble();

    final viewBoxMatch = RegExp(r'viewBox="([^"]+)"').firstMatch(svgString);
    if (viewBoxMatch != null) {
      final parts = viewBoxMatch.group(1)!.trim().split(RegExp(r'[\s,]+'));
      if (parts.length == 4) {
        svgWidth = double.tryParse(parts[2]) ?? svgWidth;
        svgHeight = double.tryParse(parts[3]) ?? svgHeight;
      }
    } else {
      final wMatch = RegExp(r'width="([\d.]+)"').firstMatch(svgString);
      final hMatch = RegExp(r'height="([\d.]+)"').firstMatch(svgString);
      if (wMatch != null) svgWidth = double.tryParse(wMatch.group(1)!) ?? svgWidth;
      if (hMatch != null) svgHeight = double.tryParse(hMatch.group(1)!) ?? svgHeight;
    }

    if (svgWidth <= 0) svgWidth = width.toDouble();
    if (svgHeight <= 0) svgHeight = width.toDouble();

    final targetHeight = (svgHeight * (width / svgWidth)).round().clamp(1, 8192);
    return svg_converter.renderSvgToPng(svgString, width, targetHeight);
  }

  // ─── Utilitaires ──────────────────────────────────────────────────────────
  Future<int> getFileSize(String path) async => (await File(path).stat()).size;

  String generateConversionId() => _uuid.v4();
}
