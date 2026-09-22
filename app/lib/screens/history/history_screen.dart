import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ConversionProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          Consumer<ConversionProvider>(
            builder: (_, provider, __) {
              if (provider.history.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: () => _confirmClear(provider),
                tooltip: 'Tout effacer',
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Consumer<ConversionProvider>(
          builder: (_, provider, __) {
            if (provider.history.isEmpty) return const _EmptyHistory();

            return ContentColumn(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                    AppSpacing.md, AppSpacing.gutter, AppSpacing.xxxl),
                itemCount: provider.history.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final record = provider.history[index];
                  return HistoryItem(
                    record: record,
                    // Sur le web, le fichier produit a été téléchargé par le
                    // navigateur : l'app n'a plus de chemin à ouvrir.
                    onTap: !kIsWeb && record.outputFilePath != null
                        ? () => OpenFile.open(record.outputFilePath!)
                        : null,
                    onDelete: () => provider.deleteHistoryItem(record.id),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmClear(ConversionProvider provider) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Effacer l\'historique ?'),
        content: const Text(
            'Les fichiers déjà convertis restent sur ton appareil, '
            'seule la liste disparaît.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              provider.clearHistory();
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: palette.sunken, shape: BoxShape.circle),
              child: Icon(Icons.history_rounded, size: 36, color: palette.textMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Rien pour l\'instant', style: context.texts.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tes conversions s\'afficheront ici,\nles cinquante dernières.',
              style: context.texts.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
