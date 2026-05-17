import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../services/downloader.dart';
import '../../widgets/widgets.dart';

class ConversionScreen extends StatefulWidget {
  final ConversionType type;

  const ConversionScreen({super.key, required this.type});

  @override
  State<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen> {
  List<String> _selectedFiles = [];
  Map<String, Uint8List> _selectedFileBytes = {};
  final _imagePicker = ImagePicker();

  Color get _typeColor {
    switch (widget.type) {
      case ConversionType.pdfToJpg:
        return AppColors.pdfColor;
      case ConversionType.jpgToPdf:
      case ConversionType.pngToPdf:
        return AppColors.jpgColor;
      case ConversionType.pngToJpg:
      case ConversionType.jpgToPng:
        return AppColors.pngColor;
      case ConversionType.docToPdf:
        return AppColors.docColor;
    }
  }

  bool get _allowMultiple {
    return widget.type == ConversionType.jpgToPdf ||
        widget.type == ConversionType.pngToPdf;
  }

  Future<void> _pickFiles() async {
    List<String> allowedExtensions;
    switch (widget.type) {
      case ConversionType.pdfToJpg:
        allowedExtensions = ['pdf'];
        break;
      case ConversionType.jpgToPdf:
        allowedExtensions = ['jpg', 'jpeg'];
        break;
      case ConversionType.pngToPdf:
      case ConversionType.pngToJpg:
        allowedExtensions = ['png'];
        break;
      case ConversionType.jpgToPng:
        allowedExtensions = ['jpg', 'jpeg'];
        break;
      case ConversionType.docToPdf:
        allowedExtensions = ['doc', 'docx'];
        break;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: _allowMultiple,
        withData: kIsWeb,
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _selectedFileBytes = {
              for (final f in result.files.where((e) => e.bytes != null))
                f.name: f.bytes!
            };
            _selectedFiles = _selectedFileBytes.keys.toList();
          } else {
            _selectedFiles = result.files
                .where((f) => f.path != null)
                .map((f) => f.path!)
                .toList();
          }
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection du fichier');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      if (_allowMultiple) {
        final images = await _imagePicker.pickMultiImage(imageQuality: 100);
        if (images.isNotEmpty) {
          setState(() {
            _selectedFiles = images.map((x) => x.path).toList();
          });
        }
      } else {
        final image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 100,
        );
        if (image != null) {
          setState(() {
            _selectedFiles = [image.path];
          });
        }
      }
    } catch (e) {
      _showError('Erreur lors de la sélection depuis la galerie');
    }
  }

  Future<void> _convert() async {
    if (_selectedFiles.isEmpty) return;

    final convProvider = context.read<ConversionProvider>();
    final authProvider = context.read<AuthProvider>();

    // Montrer le progress bottom sheet
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer<ConversionProvider>(
        builder: (_, prov, __) => ConversionProgressSheet(
          progress: prov.progress,
          conversionLabel: widget.type.label,
        ),
      ),
    );

    if (kIsWeb) {
      await convProvider.convertFromBytes(
        type: widget.type,
        inputFiles: _selectedFileBytes,
        isPremium: authProvider.user.isPremium,
      );
    } else {
      await convProvider.convert(
        type: widget.type,
        inputPaths: _selectedFiles,
        isPremium: authProvider.user.isPremium,
      );
    }

    if (!mounted) return;
    Navigator.pop(context); // Fermer le progress sheet

    if (convProvider.state == ConversionState.success) {
      authProvider.incrementConversions();
      if (kIsWeb) {
        // Télécharger automatiquement les fichiers dans le navigateur
        final bytes = convProvider.outputBytes;
        final paths = convProvider.outputPaths;
        for (int i = 0; i < bytes.length; i++) {
          downloadFile(bytes[i], paths[i]);
        }
        _showResultSheet(paths, webBytes: bytes);
      } else {
        _showResultSheet(convProvider.outputPaths);
      }
    } else if (convProvider.state == ConversionState.error) {
      _showError(convProvider.errorMessage ?? 'Une erreur est survenue');
    }
  }

  void _showResultSheet(List<String> outputPaths, {List<Uint8List>? webBytes}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConversionResultSheet(
        outputPaths: outputPaths,
        type: widget.type,
        onShare: () {
          Navigator.pop(context);
          if (!kIsWeb) ShareService().shareFiles(outputPaths);
        },
        onDownload: () {
          Navigator.pop(context);
          if (kIsWeb && webBytes != null && webBytes.isNotEmpty) {
            downloadFile(webBytes.first, outputPaths.first);
          } else if (!kIsWeb && outputPaths.isNotEmpty) {
            OpenFile.open(outputPaths.first);
          }
        },
        onConvertAgain: () {
          Navigator.pop(context);
          setState(() {
            _selectedFiles = [];
            _selectedFileBytes = {};
            context.read<ConversionProvider>().reset();
          });
        },
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: message.contains('Premium')
            ? SnackBarAction(
                label: 'Upgrade',
                textColor: Colors.white,
                onPressed: () => Navigator.pushNamed(context, '/premium'),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.label),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () {
            context.read<ConversionProvider>().reset();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: _typeColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.type.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _typeColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.1),
              const SizedBox(height: 24),

              // Zone de drop/sélection
              Text(
                _selectedFiles.isEmpty
                    ? 'Sélectionne ton fichier'
                    : '${_selectedFiles.length} fichier${_selectedFiles.length > 1 ? 's' : ''} sélectionné${_selectedFiles.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.headlineSmall,
              ).animate().fadeIn(delay: 50.ms),
              const SizedBox(height: 12),

              if (_selectedFiles.isEmpty)
                _buildDropZone()
              else
                _buildSelectedFiles(),

              const Spacer(),

              // Bouton convertir
              if (_selectedFiles.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _convert,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text('Convertir en ${widget.type.outputFormat}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _typeColor,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropZone() {
    final isImage = widget.type == ConversionType.jpgToPdf ||
        widget.type == ConversionType.pngToPdf ||
        widget.type == ConversionType.pngToJpg ||
        widget.type == ConversionType.jpgToPng;

    return Column(
      children: [
        GestureDetector(
          onTap: _pickFiles,
          child: DottedBorder(
            color: _typeColor.withOpacity(0.5),
            strokeWidth: 2,
            dashPattern: const [8, 4],
            borderType: BorderType.RRect,
            radius: const Radius.circular(20),
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_rounded,
                    size: 52,
                    color: _typeColor.withOpacity(0.7),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Appuie pour sélectionner',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _typeColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.type.inputFormat}${_allowMultiple ? ' (plusieurs fichiers)' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.95, 0.95)),

        if (isImage) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('ou', style: Theme.of(context).textTheme.bodySmall),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Ouvrir depuis la galerie'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _typeColor,
              side: BorderSide(color: _typeColor),
              minimumSize: const Size(double.infinity, 50),
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ],
    );
  }

  Widget _buildSelectedFiles() {
    return Expanded(
      child: ListView.separated(
        itemCount: _selectedFiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final path = _selectedFiles[index];
          final name = kIsWeb ? path : path.split('/').last;
          int size = 0;
          if (kIsWeb) {
            size = _selectedFileBytes[path]?.length ?? 0;
          } else {
            try {
              // ignore: avoid_slow_async_io
              size = File(path).lengthSync();
            } catch (_) {}
          }
          final sizeLabel = size < 1024 * 1024
              ? '${(size / 1024).toStringAsFixed(1)} KB'
              : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.insert_drive_file_rounded, color: _typeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(sizeLabel, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textHint),
                  onPressed: () => setState(() => _selectedFiles.removeAt(index)),
                ),
              ],
            ),
          ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn().slideX(begin: 0.1);
        },
      ),
    );
  }
}
