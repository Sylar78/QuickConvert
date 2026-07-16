import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
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
      context.read<ConversionProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          Consumer<ConversionProvider>(
            builder: (_, prov, __) {
              if (prov.history.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: () => _confirmClear(prov),
                tooltip: 'Tout effacer',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Bannière publicitaire en haut
          Consumer<AuthProvider>(
            builder: (_, auth, __) {
              if (auth.user.isPremium) return const SizedBox.shrink();
              return const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AdBannerContainer(),
              );
            },
          ),
          Expanded(
            child: Consumer<ConversionProvider>(
              builder: (_, prov, __) {
                if (prov.history.isEmpty) {
                  return _buildEmpty();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: prov.history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final record = prov.history[index];
                    return HistoryItem(
                      record: record,
                      onTap: record.outputFilePath != null
                          ? () => OpenFile.open(record.outputFilePath!)
                          : null,
                      onDelete: () => prov.deleteHistoryItem(record.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 48,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune conversion encore',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tes conversions apparaîtront ici\naprès ta première utilisation',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClear(ConversionProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Effacer l\'historique ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              prov.clearHistory();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }
}
