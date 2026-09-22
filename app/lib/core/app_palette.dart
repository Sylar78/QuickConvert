import 'package:flutter/material.dart';
import '../models/file_format.dart';

/// Les couleurs propres à QuickConvert que le [ColorScheme] de Material ne
/// couvre pas : la couleur de chaque format de fichier, l'or Premium, les
/// états, et deux surfaces de travail.
///
/// C'est une [ThemeExtension] et non une classe de constantes : c'est ce qui
/// permet au thème sombre d'exister. Un widget lit `context.palette.pdf` et
/// obtient la bonne valeur pour le thème courant, sans savoir lequel est actif.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  // Formats
  final Color pdf;
  final Color jpg;
  final Color png;
  final Color doc;
  final Color svg;

  // États
  final Color success;
  final Color warning;
  final Color info;

  // Premium
  final Color premium;
  final Color onPremium;
  final Color premiumSurface;

  // Surfaces et traits
  final Color sunken;
  final Color border;
  final Color textMuted;
  final Color shadow;

  const AppPalette({
    required this.pdf,
    required this.jpg,
    required this.png,
    required this.doc,
    required this.svg,
    required this.success,
    required this.warning,
    required this.info,
    required this.premium,
    required this.onPremium,
    required this.premiumSurface,
    required this.sunken,
    required this.border,
    required this.textMuted,
    required this.shadow,
  });

  static const light = AppPalette(
    pdf: Color(0xFFD6453F),
    jpg: Color(0xFF2E8B4F),
    png: Color(0xFF1F6FBF),
    doc: Color(0xFF1A4FA0),
    svg: Color(0xFFBF6209),
    success: Color(0xFF12794F),
    warning: Color(0xFFA35A06),
    info: Color(0xFF1F6FBF),
    premium: Color(0xFF9A6300),
    onPremium: Color(0xFFFFFFFF),
    premiumSurface: Color(0xFFFBF1DE),
    sunken: Color(0xFFF1F2F8),
    border: Color(0xFFE3E5EF),
    textMuted: Color(0xFF656C7E),
    shadow: Color(0x141A1A2E),
  );

  static const dark = AppPalette(
    pdf: Color(0xFFF08A85),
    jpg: Color(0xFF6CC488),
    png: Color(0xFF6FADE8),
    doc: Color(0xFF8BA8E4),
    svg: Color(0xFFE9A455),
    success: Color(0xFF4FC48E),
    warning: Color(0xFFE0A44E),
    info: Color(0xFF6FADE8),
    premium: Color(0xFFF0B542),
    onPremium: Color(0xFF2A1C00),
    premiumSurface: Color(0xFF2C2213),
    sunken: Color(0xFF22262F),
    border: Color(0xFF2D323C),
    textMuted: Color(0xFF98A0AF),
    shadow: Color(0x66000000),
  );

  /// La couleur associée à un format de fichier.
  Color forFormat(FileFormat format) => switch (format) {
        FileFormat.pdf => pdf,
        FileFormat.jpg => jpg,
        FileFormat.png => png,
        FileFormat.doc => doc,
        FileFormat.svg => svg,
      };

  @override
  AppPalette copyWith({
    Color? pdf,
    Color? jpg,
    Color? png,
    Color? doc,
    Color? svg,
    Color? success,
    Color? warning,
    Color? info,
    Color? premium,
    Color? onPremium,
    Color? premiumSurface,
    Color? sunken,
    Color? border,
    Color? textMuted,
    Color? shadow,
  }) {
    return AppPalette(
      pdf: pdf ?? this.pdf,
      jpg: jpg ?? this.jpg,
      png: png ?? this.png,
      doc: doc ?? this.doc,
      svg: svg ?? this.svg,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      premium: premium ?? this.premium,
      onPremium: onPremium ?? this.onPremium,
      premiumSurface: premiumSurface ?? this.premiumSurface,
      sunken: sunken ?? this.sunken,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      pdf: Color.lerp(pdf, other.pdf, t)!,
      jpg: Color.lerp(jpg, other.jpg, t)!,
      png: Color.lerp(png, other.png, t)!,
      doc: Color.lerp(doc, other.doc, t)!,
      svg: Color.lerp(svg, other.svg, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      premium: Color.lerp(premium, other.premium, t)!,
      onPremium: Color.lerp(onPremium, other.onPremium, t)!,
      premiumSurface: Color.lerp(premiumSurface, other.premiumSurface, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Les couleurs QuickConvert du thème courant.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  /// Raccourci vers le [ColorScheme] Material du thème courant.
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Raccourci vers le [TextTheme] du thème courant.
  TextTheme get texts => Theme.of(this).textTheme;
}
