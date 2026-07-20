import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import 'package:intl/intl.dart';

class HistoryItem extends StatelessWidget {
  final ConversionRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const HistoryItem({
    super.key,
    required this.record,
    this.onTap,
    this.onDelete,
  });

  Color get _typeColor {
    switch (record.conversionType) {
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
      case ConversionType.svgToPng:
        return AppColors.svgColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yy HH:mm').format(record.createdAt);

    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icône type
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _typeColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    record.conversionType.inputFormat,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _typeColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.inputFileName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          record.conversionType.label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _typeColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const Text(' · ', style: TextStyle(color: AppColors.textHint)),
                        Text(
                          record.formattedSize,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Date & status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formattedDate,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    record.isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: record.isSuccess ? AppColors.success : AppColors.error,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
