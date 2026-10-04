import 'dart:async';

import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/services.dart';

enum ConversionState { idle, loading, success, error }

/// Le résultat d'une conversion, quelle que soit la plateforme.
/// Sur mobile [names] contient des chemins de fichiers et [bytes] est vide ;
/// sur le web [names] contient des noms de fichiers et [bytes] leur contenu.
typedef _Output = ({List<String> names, List<Uint8List> bytes});

class ConversionProvider extends ChangeNotifier {
  final ConversionService _conversionService = ConversionService();
  final HistoryService _historyService = HistoryService();
  final AdmobService _adService = AdmobService();
  final AdPacing _adPacing = AdPacing();

  ConversionState _state = ConversionState.idle;
  List<String> _outputPaths = [];
  List<Uint8List> _outputBytes = [];
  String? _errorMessage;
  double _progress = 0.0;
  List<ConversionRecord> _history = [];

  ConversionProvider() {
    // L'historique alimente l'aperçu « Dernières conversions » de l'écran de
    // conversion, qui est visible avant que l'onglet Historique ne soit ouvert.
    _history = _historyService.getAll();
  }

  ConversionState get state => _state;
  List<String> get outputPaths => _outputPaths;
  List<Uint8List> get outputBytes => _outputBytes;
  String? get errorMessage => _errorMessage;
  double get progress => _progress;
  List<ConversionRecord> get history => _history;

  void loadHistory() {
    _history = _historyService.getAll();
    notifyListeners();
  }

  /// Lance une conversion.
  ///
  /// Une seule méthode pour les deux plateformes : le contrôle du quota, la
  /// vérification de taille, l'écriture dans l'historique, la publicité et la
  /// gestion d'erreur sont communs, et seul le cœur du travail
  /// ([_runOnFiles] / [_runOnBytes]) diffère. Auparavant, `convert` et
  /// `convertFromBytes` répétaient ces cent soixante-dix lignes chacune de leur
  /// côté, avec le risque de ne corriger un bug que dans une des deux.
  Future<void> convert({
    required ConversionType type,
    required List<SourceFile> files,
    required bool isPremium,
    int quality = 90,
  }) async {
    if (files.isEmpty) return;

    if (!isPremium &&
        _historyService.todayCount >= AppConstants.freeConversionsPerDay) {
      _fail(
        'Tu as utilisé tes ${AppConstants.freeConversionsPerDay} conversions '
        'gratuites du jour. Passe à Premium pour continuer sans limite.',
      );
      return;
    }

    final oversized = files.firstWhereOrNull(
      (f) => f.sizeBytes > AppConstants.maxFileSizeBytes,
    );
    if (oversized != null) {
      _fail(
        '« ${oversized.name} » dépasse ${AppConstants.maxFileSizeLabel}. '
        'Choisis un fichier plus léger.',
      );
      return;
    }

    _state = ConversionState.loading;
    _outputPaths = [];
    _outputBytes = [];
    _errorMessage = null;
    _progress = 0.0;
    notifyListeners();

    // La publicité passe au lancement, et la conversion tourne pendant
    // qu'elle s'affiche : le résultat attend l'utilisateur quand il la ferme.
    // Elle n'est jamais attendue, donc une annonce absente ou en panne ne
    // retarde ni ne fait échouer la conversion.
    if (!isPremium) unawaited(_maybeShowAd());

    final id = _conversionService.generateConversionId();
    final source = files.first;

    try {
      _setProgress(0.25);
      final output = kIsWeb
          ? await _runOnBytes(type, files, quality)
          : await _runOnFiles(type, files, quality);
      _setProgress(0.9);

      _outputPaths = output.names;
      _outputBytes = output.bytes;

      final outputSize = output.bytes.isNotEmpty
          ? output.bytes.first.length
          : (output.names.isNotEmpty
              ? await _conversionService.getFileSize(output.names.first)
              : null);

      await _record(
        id: id,
        type: type,
        source: source,
        outputPath: output.names.isNotEmpty ? output.names.first : null,
        outputSize: outputSize,
        isSuccess: true,
      );

      _state = ConversionState.success;
      _setProgress(1.0);
    } catch (e) {
      await _record(
        id: id,
        type: type,
        source: source,
        isSuccess: false,
        errorMessage: e.toString(),
      );

      _state = ConversionState.error;
      _errorMessage = _readableError(e);
      debugPrint('Conversion error: $e');
    }

    notifyListeners();
  }

  Future<void> _maybeShowAd() async {
    if (kIsWeb || !_adPacing.registerConversion()) return;
    if (await _adService.showInterstitial()) _adPacing.markShown();
  }

  // ─── Cœur de la conversion, par plateforme ────────────────────────────────

  Future<_Output> _runOnFiles(
    ConversionType type,
    List<SourceFile> files,
    int quality,
  ) async {
    final paths = files.map((f) => f.path!).toList();

    final names = switch (type) {
      ConversionType.pdfToJpg => await _conversionService.pdfToJpg(paths.first),
      ConversionType.jpgToPdf ||
      ConversionType.pngToPdf =>
        [await _conversionService.imagesToPdf(paths)],
      ConversionType.pngToJpg =>
        [await _conversionService.pngToJpg(paths.first, quality: quality)],
      ConversionType.jpgToPng => [await _conversionService.jpgToPng(paths.first)],
      ConversionType.docToPdf => [await _conversionService.docToPdf(paths.first)],
      ConversionType.svgToPng => [await _conversionService.svgToPng(paths.first)],
    };

    return (names: names, bytes: const <Uint8List>[]);
  }

  Future<_Output> _runOnBytes(
    ConversionType type,
    List<SourceFile> files,
    int quality,
  ) async {
    final first = files.first;
    final firstBytes = first.bytes!;

    switch (type) {
      case ConversionType.pdfToJpg:
        final pages = await _conversionService.pdfToJpgBytes(firstBytes);
        return (
          names: [
            for (int i = 0; i < pages.length; i++)
              '${_stem(first.name)}_page_${i + 1}.jpg',
          ],
          bytes: pages,
        );

      case ConversionType.jpgToPdf:
      case ConversionType.pngToPdf:
        final pdf = await _conversionService
            .imagesToPdfBytes(files.map((f) => f.bytes!).toList());
        return (names: ['${_stem(first.name)}.pdf'], bytes: [pdf]);

      case ConversionType.pngToJpg:
        final jpg = await _conversionService
            .imageFormatBytes(firstBytes, toPng: false, quality: quality);
        return (names: ['${_stem(first.name)}.jpg'], bytes: [jpg]);

      case ConversionType.jpgToPng:
        final png =
            await _conversionService.imageFormatBytes(firstBytes, toPng: true);
        return (names: ['${_stem(first.name)}.png'], bytes: [png]);

      case ConversionType.docToPdf:
        final pdf = await _conversionService.docToPdfBytes(firstBytes, first.name);
        return (names: ['${_stem(first.name)}.pdf'], bytes: [pdf]);

      case ConversionType.svgToPng:
        final png = await _conversionService.svgToPngBytes(firstBytes);
        return (names: ['${_stem(first.name)}.png'], bytes: [png]);
    }
  }

  // ─── Historique ───────────────────────────────────────────────────────────

  Future<void> _record({
    required String id,
    required ConversionType type,
    required SourceFile source,
    String? outputPath,
    int? outputSize,
    required bool isSuccess,
    String? errorMessage,
  }) async {
    await _historyService.add(ConversionRecord(
      id: id,
      typeIndex: type.index.toString(),
      inputFileName: source.name,
      outputFilePath: outputPath,
      createdAt: DateTime.now(),
      inputFileSizeBytes: source.sizeBytes,
      outputFileSizeBytes: outputSize,
      isSuccess: isSuccess,
      errorMessage: errorMessage,
    ));
    _history = _historyService.getAll();
  }

  Future<void> deleteHistoryItem(String id) async {
    await _historyService.delete(id);
    _history = _historyService.getAll();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _historyService.clearAll();
    _history = [];
    notifyListeners();
  }

  // ─── État ─────────────────────────────────────────────────────────────────

  void _fail(String message) {
    _state = ConversionState.error;
    _errorMessage = message;
    notifyListeners();
  }

  void _setProgress(double value) {
    _progress = value;
    notifyListeners();
  }

  void reset() {
    _state = ConversionState.idle;
    _outputPaths = [];
    _outputBytes = [];
    _errorMessage = null;
    _progress = 0.0;
    notifyListeners();
  }

  /// Un message lisible : les [ConversionException] en portent déjà un, le
  /// reste est une erreur technique qu'on ne montre pas telle quelle.
  String _readableError(Object error) {
    if (error is ConversionException) return error.message;
    return 'La conversion a échoué. Réessaie avec un autre fichier.';
  }

  String _stem(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }
}

extension _FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
