import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/core.dart';
import '../../models/models.dart';

class ConversionCard extends StatelessWidget {
  final ConversionType type;
  final VoidCallback onTap;
  final int index;

  const ConversionCard({
    super.key,
    required this.type,
    required this.onTap,
    required this.index,
  });

  Color get _color {
    switch (type) {
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

  IconData get _icon {
    switch (type) {
      case ConversionType.pdfToJpg:
        return Icons.picture_as_pdf_rounded;
      case ConversionType.jpgToPdf:
      case ConversionType.pngToPdf:
        return Icons.image_rounded;
      case ConversionType.pngToJpg:
      case ConversionType.jpgToPng:
        return Icons.photo_filter_rounded;
      case ConversionType.docToPdf:
        return Icons.description_rounded;
      case ConversionType.svgToPng:
        return Icons.draw_rounded;
    }
  }

  IconData _formatIcon(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'svg':
        return Icons.draw_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withAlpha(18), width: 1),
        boxShadow: [
          BoxShadow(
            color: _color.withAlpha(20),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: _color.withAlpha(25),
          highlightColor: _color.withAlpha(13),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                // Zone principale — grands chips format
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _LargeFormatChip(
                          label: type.inputFormat,
                          icon: _formatIcon(type.inputFormat),
                          color: _color,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 22, color: _color.withAlpha(140)),
                      ),
                      Expanded(
                        child: _LargeFormatChip(
                          label: type.outputFormat,
                          icon: _formatIcon(type.outputFormat),
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Label en bas
                Text(
                  type.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  type.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * index))
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.97, 0.97), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutCubic);
  }
}

class _LargeFormatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _LargeFormatChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(30), width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
