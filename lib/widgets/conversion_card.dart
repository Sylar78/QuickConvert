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
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _color.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: _color.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône avec fond coloré
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon, color: _color, size: 26),
                  ),
                  const Spacer(),

                  // Badges format
                  Row(
                    children: [
                      _FormatBadge(label: type.inputFormat, color: _color),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 6),
                      _FormatBadge(label: type.outputFormat, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Label principal
                  Text(
                    type.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    type.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 80 * index))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

class _FormatBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _FormatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
