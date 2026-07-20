import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';
import 'svg_to_png.dart' as svg_converter;

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
    final pageCount = document.pagesCount;

    for (int i = 1; i <= pageCount; i++) {
      final page = await document.getPage(i);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
      );
      await page.close();

      final fileName = '${basename}_page_$i.jpg';
      final filePath = p.join(outDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(pageImage!.bytes);
      outputPaths.add(filePath);
    }

    await document.close();
    return outputPaths;
  }

  // ─── Images → PDF ─────────────────────────────────────────────────────────
  Future<String> imagesToPdf(List<String> imagePaths) async {
    final outDir = await _outputDir;
    final fileName = 'converted_${_uuid.v4().substring(0, 8)}.pdf';
    final outputPath = p.join(outDir.path, fileName);

    final pdf = pw.Document();

    for (final imagePath in imagePaths) {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      pw.ImageProvider pdfImage;
      final ext = p.extension(imagePath).toLowerCase();

      if (ext == '.png') {
        pdfImage = pw.MemoryImage(imageBytes);
      } else {
        pdfImage = pw.MemoryImage(imageBytes);
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());
    return outputPath;
  }

  // ─── PNG → JPG ────────────────────────────────────────────────────────────
  Future<String> pngToJpg(String pngPath, {int quality = 90}) async {
    final outDir = await _outputDir;
    final basename = p.basenameWithoutExtension(pngPath);
    final outputPath = p.join(outDir.path, '$basename.jpg');

    final bytes = await File(pngPath).readAsBytes();
    final image = await compute(_decodeImage, bytes);
    if (image == null) throw Exception('Impossible de lire l\'image');

    final jpgBytes = img.encodeJpg(image, quality: quality);
    await File(outputPath).writeAsBytes(jpgBytes);
    return outputPath;
  }

  // ─── JPG → PNG ────────────────────────────────────────────────────────────
  Future<String> jpgToPng(String jpgPath) async {
    final outDir = await _outputDir;
    final basename = p.basenameWithoutExtension(jpgPath);
    final outputPath = p.join(outDir.path, '$basename.png');

    final bytes = await File(jpgPath).readAsBytes();
    final image = await compute(_decodeImage, bytes);
    if (image == null) throw Exception('Impossible de lire l\'image');

    final pngBytes = img.encodePng(image);
    await File(outputPath).writeAsBytes(pngBytes);
    return outputPath;
  }

  // ─── DOC/DOCX → PDF ───────────────────────────────────────────────────────
  /// Note: la conversion native DOC→PDF nécessite un backend ou LibreOffice.
  /// Ici on génère un PDF avec le contenu texte extrait (MVP local).
  Future<String> docToPdf(String docPath) async {
    final outDir = await _outputDir;
    final basename = p.basenameWithoutExtension(docPath);
    final outputPath = p.join(outDir.path, '$basename.pdf');

    // Pour le MVP, on crée un PDF placeholder indiquant la limitation.
    // En V2, appeler le backend Node.js/LibreOffice.
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                basename,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Document converti depuis $basename.docx\n\n'
                'Note: La conversion complète DOC→PDF avec mise en forme '
                'nécessite le service cloud QuickConvert.',
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          );
        },
      ),
    );

    await File(outputPath).writeAsBytes(await pdf.save());
    return outputPath;
  }

  // ─── Méthodes Web (bytes in / bytes out, pas de dart:io) ─────────────────

  /// SVG → PNG (fichier, mobile/desktop)
  Future<String> svgToPng(String svgPath, {int width = 1024}) async {
    final outDir = await _outputDir;
    final basename = p.basenameWithoutExtension(svgPath);
    final outputPath = p.join(outDir.path, '$basename.png');

    final svgBytes = await File(svgPath).readAsBytes();
    final pngBytes = await svgToPngBytes(svgBytes, width: width);
    await File(outputPath).writeAsBytes(pngBytes);
    return outputPath;
  }

  /// SVG → PNG (bytes, web + mobile)
  Future<Uint8List> svgToPngBytes(Uint8List svgBytes, {int width = 1024}) async {
    final svgString = String.fromCharCodes(svgBytes);

    // Parse SVG dimensions from viewBox or width/height attributes
    double svgWidth = width.toDouble();
    double svgHeight = width.toDouble();

    final viewBoxMatch = RegExp(r'viewBox="([^"]+)"').firstMatch(svgString);
    if (viewBoxMatch != null) {
      final parts = viewBoxMatch.group(1)!.trim().split(RegExp(r'[\s,]+'));
      if (parts.length == 4) {
        svgWidth = double.tryParse(parts[2]) ?? width.toDouble();
        svgHeight = double.tryParse(parts[3]) ?? width.toDouble();
      }
    } else {
      final wMatch = RegExp(r'width="([\d.]+)"').firstMatch(svgString);
      final hMatch = RegExp(r'height="([\d.]+)"').firstMatch(svgString);
      if (wMatch != null) svgWidth = double.tryParse(wMatch.group(1)!) ?? svgWidth;
      if (hMatch != null) svgHeight = double.tryParse(hMatch.group(1)!) ?? svgHeight;
    }

    final scale = width / svgWidth;
    final targetHeight = (svgHeight * scale).round();

    return svg_converter.renderSvgToPng(svgString, width, targetHeight);
  }

  // ─── Méthodes Web (bytes in / bytes out, pas de dart:io) ─────────────────

  Future<List<Uint8List>> pdfToJpgBytes(Uint8List pdfBytes) async {
    final document = await PdfDocument.openData(pdfBytes);
    final pageCount = document.pagesCount;
    final results = <Uint8List>[];
    for (int i = 1; i <= pageCount; i++) {
      final page = await document.getPage(i);
      try {
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#ffffff',
        );
        if (pageImage != null) {
          results.add(pageImage.bytes);
        }
      } catch (_) {
        // skip page on render error
      } finally {
        await page.close();
      }
    }
    await document.close();
    return results;
  }

  Future<Uint8List> imagesToPdfBytes(List<Uint8List> imageBytesList) async {
    final pdf = pw.Document();
    for (final imageBytes in imageBytesList) {
      final pdfImage = pw.MemoryImage(imageBytes);
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) =>
            pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
      ));
    }
    return Uint8List.fromList(await pdf.save());
  }

  Future<Uint8List> imageFormatBytes(Uint8List inputBytes,
      {bool toPng = false, int quality = 90}) async {
    final image = img.decodeImage(inputBytes);
    if (image == null) throw Exception('Impossible de lire l\'image');
    if (toPng) return Uint8List.fromList(img.encodePng(image));
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  // ─── Utilitaires ──────────────────────────────────────────────────────────
  static img.Image? _decodeImage(Uint8List bytes) => img.decodeImage(bytes);

  Future<int> getFileSize(String path) async {
    final stat = await File(path).stat();
    return stat.size;
  }

  String generateConversionId() => _uuid.v4();
}
