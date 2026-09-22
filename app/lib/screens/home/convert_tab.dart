import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/downloader.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';

/// L'écran de conversion, en un seul morceau.
///
/// Avant la refonte, ce parcours tenait en deux temps : choisir un couple de
/// formats parmi sept tuiles, puis, sur un autre écran, choisir un fichier
/// compatible. L'ordre est maintenant celui du geste réel — le fichier d'abord,
/// la destination ensuite, parmi ce que ce fichier permet.
class ConvertTab extends StatefulWidget {
  final VoidCallback onSeeHistory;

  const ConvertTab({super.key, required this.onSeeHistory});

  @override
  State<ConvertTab> createState() => _ConvertTabState();
}

class _ConvertTabState extends State<ConvertTab> {
  final _imagePicker = ImagePicker();

  List<SourceFile> _files = [];
  FileFormat? _inputFormat;
  ConversionRoute? _route;

  /// Les destinations possibles pour la sélection courante. Avec plusieurs
  /// fichiers, seules les conversions qui savent les regrouper sont offertes.
  List<ConversionRoute> get _routes {
    if (_inputFormat == null) return const [];
    final all = ConversionCatalog.fromFormat(_inputFormat!);
    if (_files.length > 1) {
      return all.where((r) => r.supportsBatch).toList();
    }
    return all;
  }

  // ─── Sélection de fichiers ────────────────────────────────────────────────

  Future<void> _pickFiles({bool append = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ConversionCatalog.inputExtensions,
        allowMultiple: true,
        withData: kIsWeb,
      );
      if (result == null) return;

      _adopt([
        for (final f in result.files)
          if (kIsWeb ? f.bytes != null : f.path != null)
            SourceFile(
              name: f.name,
              path: kIsWeb ? null : f.path,
              bytes: kIsWeb ? f.bytes : null,
              sizeBytes: f.size,
            ),
      ], append: append);
    } catch (_) {
      _notify('Ce fichier n\'a pas pu être ouvert.');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 100);
      if (images.isEmpty) return;

      final picked = <SourceFile>[];
      for (final image in images) {
        final bytes = kIsWeb ? await image.readAsBytes() : null;
        picked.add(SourceFile(
          name: image.name,
          path: kIsWeb ? null : image.path,
          bytes: bytes,
          sizeBytes: bytes?.length ?? await image.length(),
        ));
      }
      _adopt(picked);
    } catch (_) {
      _notify('La galerie n\'a pas pu être ouverte.');
    }
  }

  /// Prend en charge une sélection : détermine le format de travail, écarte ce
  /// qui ne va pas avec, et choisit une destination possible.
  ///
  /// Avec [append], la sélection s'ajoute à celle en cours (bouton « Ajouter un
  /// fichier ») au lieu de la remplacer.
  void _adopt(List<SourceFile> picked, {bool append = false}) {
    if (picked.isEmpty) return;

    final existing = append ? _files : const <SourceFile>[];
    final format = (append ? _inputFormat : null) ??
        ConversionCatalog.detect(picked.first.name);
    if (format == null) {
      _notify('QuickConvert ne sait pas encore ouvrir ce format.');
      return;
    }

    // On ne mélange pas les formats dans une même conversion, et un fichier
    // déjà présent ne s'ajoute pas deux fois.
    final names = existing.map((f) => f.name).toSet();
    final incoming = picked
        .where((f) => ConversionCatalog.detect(f.name) == format)
        .where((f) => names.add(f.name))
        .toList();
    final droppedOtherFormats =
        incoming.length + existing.length < picked.length + existing.length;

    if (incoming.isEmpty) {
      if (droppedOtherFormats) {
        _notify('Cette conversion ne prend que des fichiers ${format.label}.');
      }
      return;
    }

    var kept = [...existing, ...incoming];

    final batchRoutes =
        ConversionCatalog.fromFormat(format).where((r) => r.supportsBatch).toList();
    var droppedForBatch = false;
    if (kept.length > 1 && batchRoutes.isEmpty) {
      kept = [kept.first];
      droppedForBatch = true;
    }

    final available =
        kept.length > 1 ? batchRoutes : ConversionCatalog.fromFormat(format);

    setState(() {
      _files = kept;
      _inputFormat = format;
      // On garde la destination choisie si elle reste possible.
      _route = available.firstWhere(
        (r) => r.type == _route?.type,
        orElse: () => available.first,
      );
    });

    if (droppedForBatch) {
      _notify('Un seul fichier ${format.label} à la fois pour cette conversion.');
    } else if (droppedOtherFormats) {
      _notify('Seuls les fichiers ${format.label} ont été gardés.');
    }
  }

  void _removeAt(int index) {
    final remaining = [..._files]..removeAt(index);

    if (remaining.isEmpty) {
      _clear();
      return;
    }

    setState(() {
      _files = remaining;
      // Une destination réservée au lot n'a plus lieu d'être avec un seul
      // fichier, et inversement : on revalide le choix courant.
      final available = remaining.length > 1
          ? ConversionCatalog.fromFormat(_inputFormat!)
              .where((r) => r.supportsBatch)
              .toList()
          : ConversionCatalog.fromFormat(_inputFormat!);
      if (!available.any((r) => r.type == _route?.type)) {
        _route = available.first;
      }
    });
  }

  void _clear() {
    setState(() {
      _files = [];
      _inputFormat = null;
      _route = null;
    });
    context.read<ConversionProvider>().reset();
  }

  // ─── Conversion ───────────────────────────────────────────────────────────

  Future<void> _convert() async {
    final route = _route;
    if (route == null || _files.isEmpty) return;

    final conversions = context.read<ConversionProvider>();
    final auth = context.read<AuthProvider>();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer<ConversionProvider>(
        builder: (_, provider, __) => ConversionProgressSheet(
          progress: provider.progress,
          conversionLabel: route.label,
        ),
      ),
    );

    await conversions.convert(
      type: route.type,
      files: _files,
      isPremium: auth.user.isPremium,
    );

    if (!mounted) return;
    Navigator.pop(context); // ferme la feuille de progression

    // Le quota se relit depuis l'historique : la conversion vient d'y être
    // écrite, le compteur affiché et la limite appliquée restent d'accord.
    auth.refreshQuota();

    if (conversions.state == ConversionState.success) {
      final names = conversions.outputPaths;
      final bytes = conversions.outputBytes;

      if (kIsWeb) {
        for (int i = 0; i < bytes.length && i < names.length; i++) {
          downloadFile(bytes[i], names[i]);
        }
      }
      _showResult(route, names, bytes);
    } else if (conversions.state == ConversionState.error) {
      _notify(conversions.errorMessage ?? 'La conversion a échoué.',
          offerUpgrade: !auth.user.canConvert);
    }
  }

  void _showResult(
    ConversionRoute route,
    List<String> names,
    List<Uint8List> bytes,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConversionResultSheet(
        outputNames: names,
        route: route,
        canShare: !kIsWeb,
        onShare: () {
          Navigator.pop(context);
          if (!kIsWeb) ShareService().shareFiles(names);
        },
        onOpen: () {
          Navigator.pop(context);
          if (kIsWeb) {
            if (bytes.isNotEmpty) downloadFile(bytes.first, names.first);
          } else if (names.isNotEmpty) {
            OpenFile.open(names.first);
          }
        },
        onConvertAgain: () {
          Navigator.pop(context);
          _clear();
        },
      ),
    );
  }

  void _notify(String message, {bool offerUpgrade = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: offerUpgrade
            ? SnackBarAction(
                label: 'Premium',
                onPressed: () => Navigator.pushNamed(context, '/premium'),
              )
            : null,
      ));
  }

  // ─── Rendu ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final history = context.watch<ConversionProvider>().history;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter, AppSpacing.xl, AppSpacing.gutter, AppSpacing.xxxl),
        child: ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(isPremium: user.isPremium),
              const SizedBox(height: AppSpacing.xl),

              if (!user.isPremium) ...[
                QuotaCard(
                  remaining: user.remainingConversions,
                  total: AppConstants.freeConversionsPerDay,
                  onUpgrade: () => Navigator.pushNamed(context, '/premium'),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              if (_files.isEmpty)
                _buildEmptyState()
              else
                _buildSelection(),

              if (history.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                _RecentConversions(
                  records: history.take(3).toList(),
                  onSeeAll: widget.onSeeHistory,
                ),
              ],

              if (!user.isPremium) ...[
                const SizedBox(height: AppSpacing.xl),
                const AdBannerContainer(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropZone(onTap: _pickFiles),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _pickFromGallery,
          icon: const Icon(Icons.photo_library_rounded, size: 20),
          label: const Text('Depuis la galerie'),
        ),
      ],
    );
  }

  Widget _buildSelection() {
    final route = _route!;
    final format = _inputFormat!;
    final canBatch = _routes.any((r) => r.supportsBatch);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _files.length > 1
                    ? '${_files.length} fichiers ${format.label}'
                    : 'Ton fichier',
                style: context.texts.headlineSmall,
              ),
            ),
            TextButton(onPressed: _clear, child: const Text('Tout retirer')),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        for (int i = 0; i < _files.length; i++) ...[
          SourceFileTile(
            file: _files[i],
            format: format,
            onRemove: () => _removeAt(i),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        if (canBatch)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _pickFiles(append: true),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter un fichier'),
            ),
          ),

        const SizedBox(height: AppSpacing.lg),
        OutputFormatSelector(
          routes: _routes,
          selected: route,
          onSelected: (r) => setState(() => _route = r),
        ),

        const SizedBox(height: AppSpacing.xl),
        ElevatedButton.icon(
          onPressed: _convert,
          icon: const Icon(Icons.auto_awesome_rounded, size: 20),
          label: Text('Convertir en ${route.to.label}'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final bool isPremium;

  const _Header({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppConstants.appName, style: context.texts.displaySmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Dépose un fichier, choisis ta sortie.',
                style: context.texts.bodyMedium,
              ),
            ],
          ),
        ),
        if (isPremium) const PremiumChip(),
      ],
    );
  }
}

class _RecentConversions extends StatelessWidget {
  final List<ConversionRecord> records;
  final VoidCallback onSeeAll;

  const _RecentConversions({required this.records, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Dernières conversions', style: context.texts.titleSmall),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('Tout voir')),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final record in records) ...[
          HistoryItem(
            record: record,
            dense: true,
            onTap: record.outputFilePath != null && !kIsWeb
                ? () => OpenFile.open(record.outputFilePath!)
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
