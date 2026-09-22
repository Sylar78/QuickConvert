import 'package:flutter/material.dart';
import '../models/file_format.dart';

/// L'icône associée à chaque format de fichier.
///
/// La couleur, elle, vient de `context.palette.forFormat(...)` : elle change
/// avec le thème, l'icône non.
class FormatStyle {
  const FormatStyle._();

  static IconData iconFor(FileFormat format) => switch (format) {
        FileFormat.pdf => Icons.picture_as_pdf_rounded,
        FileFormat.jpg => Icons.photo_rounded,
        FileFormat.png => Icons.image_rounded,
        FileFormat.doc => Icons.description_rounded,
        FileFormat.svg => Icons.polyline_rounded,
      };
}
