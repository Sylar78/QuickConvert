import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/models.dart';

class ConversionResultSheet extends StatelessWidget {
  final List<String> outputPaths;
  final ConversionType type;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onConvertAgain;

  const ConversionResultSheet({
    super.key,
    required this.outputPaths,
    required this.type,
    required this.onShare,
    required this.onDownload,
    required this.onConvertAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Succès
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 46,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Conversion réussie ! 🎉',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),

          Text(
            '${outputPaths.length} fichier${outputPaths.length > 1 ? 's' : ''} converti${outputPaths.length > 1 ? 's' : ''} avec succès',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Partager'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Ouvrir'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: onConvertAgain,
            child: const Text('Convertir un autre fichier'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
