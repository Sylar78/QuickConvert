import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const Color primary = Color(0xFF6C63FF);       // Violet principal
  static const Color primaryLight = Color(0xFF9C94FF);
  static const Color primaryDark = Color(0xFF4B44CC);

  // Accent
  static const Color accent = Color(0xFF3ECFCF);        // Turquoise accent

  // Backgrounds
  static const Color background = Color(0xFFF8F9FF);    // Fond très clair
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F1FC);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7080);
  static const Color textHint = Color(0xFFB0B7C3);

  // Conversions — couleurs par type
  static const Color pdfColor = Color(0xFFFF5757);      // Rouge PDF
  static const Color jpgColor = Color(0xFF4CAF50);      // Vert JPG
  static const Color pngColor = Color(0xFF2196F3);      // Bleu PNG
  static const Color docColor = Color(0xFF1565C0);      // Bleu foncé DOC

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF29B6F6);

  // Premium gold
  static const Color premium = Color(0xFFFFB300);
  static const Color premiumLight = Color(0xFFFFF8E1);

  // Shadows
  static const Color shadow = Color(0x1A6C63FF);
  static const Color shadowDark = Color(0x266C63FF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF9C94FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF8F9FF), Color(0xFFEEEEFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
