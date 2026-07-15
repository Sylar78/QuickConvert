import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../services/services.dart';
import '../core/constants.dart';

enum ConversionState { idle, loading, success, error }

class ConversionProvider extends ChangeNotifier {
  final ConversionService _conversionService = ConversionService();
  final HistoryService _historyService = HistoryService();
  final AdmobService _adService = AdmobService();

  ConversionState _state = ConversionState.idle;
  List<String> _outputPaths = [];
  List<Uint8List> _outputBytes = [];
  String? _errorMessage;
  double _progress = 0.0;
  List<ConversionRecord> _history = [];

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

  Future<void> convert({
    required ConversionType type,
    required List<String> inputPaths,
    required bool isPremium,
    int quality = 90,
  }) async {
    if (inputPaths.isEmpty) return;

    // Vérifier la limite quotidienne
    if (!isPremium && _historyService.todayCount >= AppConstants.freeConversionsPerDay) {
      _state = ConversionState.error;
      _errorMessage = 'Tu as atteint ta limite de ${AppConstants.freeConversionsPerDay} conversions aujourd\'hui.\nPasse à Premium pour des conversions illimitées !';
      notifyListeners();
      return;
    }

    _state = ConversionState.loading;
    _outputPaths = [];
    _errorMessage = null;
    _progress = 0.0;
    notifyListeners();

    final id = _conversionService.generateConversionId();
    int inputSize = 0;
    String inputFileName = inputPaths.first.split('/').last;
    if (!kIsWeb) {
      try {
        final inputFile = File(inputPaths.first);
        inputSize = await inputFile.length();
        inputFileName = inputFile.path.split('/').last;

        // Validate file size
        if (inputSize > AppConstants.maxFileSizeBytes) {
          _state = ConversionState.error;
          _errorMessage = 'Le fichier est trop volumineux (max 50 MB).';
          notifyListeners();
          return;
        }
      } catch (_) {}
    }

    try {
      List<String> results = [];

      switch (type) {
        case ConversionType.pdfToJpg:
          _setProgress(0.2);
          results = await _conversionService.pdfToJpg(inputPaths.first);
          break;

        case ConversionType.jpgToPdf:
        case ConversionType.pngToPdf:
          _setProgress(0.3);
          final pdfPath = await _conversionService.imagesToPdf(inputPaths);
          results = [pdfPath];
          break;

        case ConversionType.pngToJpg:
          _setProgress(0.3);
          final jpgPath = await _conversionService.pngToJpg(inputPaths.first, quality: quality);
          results = [jpgPath];
          break;

        case ConversionType.jpgToPng:
          _setProgress(0.3);
          final pngPath = await _conversionService.jpgToPng(inputPaths.first);
          results = [pngPath];
          break;

        case ConversionType.docToPdf:
          _setProgress(0.5);
          final pdfPath = await _conversionService.docToPdf(inputPaths.first);
          results = [pdfPath];
          break;
      }

      _setProgress(0.9);

      final outputSize = results.isNotEmpty
          ? await _conversionService.getFileSize(results.first)
          : null;

      // Sauvegarder dans l'historique
      final record = ConversionRecord(
        id: id,
        typeIndex: type.index.toString(),
        inputFileName: inputFileName,
        outputFilePath: results.isNotEmpty ? results.first : null,
        createdAt: DateTime.now(),
        inputFileSizeBytes: inputSize,
        outputFileSizeBytes: outputSize,
        isSuccess: true,
      );
      await _historyService.add(record);
      _history = _historyService.getAll();

      _outputPaths = results;
      _state = ConversionState.success;
      _setProgress(1.0);

      // Montrer une pub interstitielle pour les utilisateurs gratuits
      if (!isPremium) {
        await _adService.showInterstitial();
      }
    } catch (e) {
      // Sauvegarder l'échec dans l'historique
      final record = ConversionRecord(
        id: id,
        typeIndex: type.index.toString(),
        inputFileName: inputFileName,
        createdAt: DateTime.now(),
        inputFileSizeBytes: inputSize,
        isSuccess: false,
        errorMessage: e.toString(),
      );
      await _historyService.add(record);
      _history = _historyService.getAll();

      _state = ConversionState.error;
      _errorMessage = 'Une erreur est survenue lors de la conversion.\n${e.toString()}';
      debugPrint('Conversion error: $e');
    }

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

  /// Version web : entrée = Map<nomFichier, bytes>, sortie = bytes en mémoire
  Future<void> convertFromBytes({
    required ConversionType type,
    required Map<String, Uint8List> inputFiles,
    required bool isPremium,
    int quality = 90,
  }) async {
    if (inputFiles.isEmpty) return;

    if (!isPremium &&
        _historyService.todayCount >= AppConstants.freeConversionsPerDay) {
      _state = ConversionState.error;
      _errorMessage =
          'Tu as atteint ta limite de ${AppConstants.freeConversionsPerDay} conversions aujourd\'hui.\nPasse à Premium pour des conversions illimitées !';
      notifyListeners();
      return;
    }

    _state = ConversionState.loading;
    _outputPaths = [];
    _outputBytes = [];
    _errorMessage = null;
    _progress = 0.0;
    notifyListeners();

    final id = _conversionService.generateConversionId();
    final firstName = inputFiles.keys.first;
    final firstBytes = inputFiles.values.first;
    final inputSize = firstBytes.length;

    // Validate file size
    if (inputSize > AppConstants.maxFileSizeBytes) {
      _state = ConversionState.error;
      _errorMessage = 'Le fichier est trop volumineux (max 50 MB).';
      notifyListeners();
      return;
    }

    try {
      switch (type) {
        case ConversionType.pdfToJpg:
          _setProgress(0.2);
          _outputBytes = await _conversionService.pdfToJpgBytes(firstBytes);
          _outputPaths = _outputBytes.asMap().entries
              .map((e) =>
                  '${firstName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')}_page_${e.key + 1}.jpg')
              .toList();
          break;

        case ConversionType.jpgToPdf:
        case ConversionType.pngToPdf:
          _setProgress(0.3);
          final pdfBytes = await _conversionService
              .imagesToPdfBytes(inputFiles.values.toList());
          _outputBytes = [pdfBytes];
          _outputPaths = ['converted.pdf'];
          break;

        case ConversionType.pngToJpg:
          _setProgress(0.3);
          final jpgBytes = await _conversionService
              .imageFormatBytes(firstBytes, toPng: false, quality: quality);
          _outputBytes = [jpgBytes];
          _outputPaths = [
            '${firstName.replaceAll(RegExp(r'\.png$', caseSensitive: false), '')}.jpg'
          ];
          break;

        case ConversionType.jpgToPng:
          _setProgress(0.3);
          final pngBytes = await _conversionService
              .imageFormatBytes(firstBytes, toPng: true);
          _outputBytes = [pngBytes];
          _outputPaths = [
            '${firstName.replaceAll(RegExp(r'\.(jpg|jpeg)$', caseSensitive: false), '')}.png'
          ];
          break;

        case ConversionType.docToPdf:
          _setProgress(0.2);
          final uri = Uri.parse('${AppConstants.backendUrl}/api/convert/doc-to-pdf');
          final request = http.MultipartRequest('POST', uri);
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            firstBytes,
            filename: firstName,
          ));
          _setProgress(0.5);
          final streamed = await request.send();
          final resp = await http.Response.fromStream(streamed);
          if (resp.statusCode == 200) {
            _outputBytes = [resp.bodyBytes];
            _outputPaths = [
              '${firstName.replaceAll(RegExp(r'\.(docx?)$', caseSensitive: false), '')}.pdf'
            ];
          } else {
            final err = jsonDecode(resp.body);
            throw Exception(err['error'] ?? 'Erreur backend');
          }
          break;      }

      _setProgress(0.9);

      // Sauvegarder dans l'historique
      final outputSize = _outputBytes.isNotEmpty ? _outputBytes.first.length : null;
      final record = ConversionRecord(
        id: id,
        typeIndex: type.index.toString(),
        inputFileName: firstName,
        outputFilePath: _outputPaths.isNotEmpty ? _outputPaths.first : null,
        createdAt: DateTime.now(),
        inputFileSizeBytes: inputSize,
        outputFileSizeBytes: outputSize,
        isSuccess: true,
      );
      await _historyService.add(record);
      _history = _historyService.getAll();

      _state = ConversionState.success;
      _setProgress(1.0);

      if (!isPremium) {
        await _adService.showInterstitial();
      }
    } catch (e) {
      // Sauvegarder l'échec dans l'historique
      final record = ConversionRecord(
        id: id,
        typeIndex: type.index.toString(),
        inputFileName: firstName,
        createdAt: DateTime.now(),
        inputFileSizeBytes: inputSize,
        isSuccess: false,
        errorMessage: e.toString(),
      );
      await _historyService.add(record);
      _history = _historyService.getAll();

      _state = ConversionState.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('Web conversion error: $e');
    }

    notifyListeners();
  }
}
