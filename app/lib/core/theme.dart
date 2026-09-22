import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_palette.dart';
import 'app_spacing.dart';

/// Les deux thèmes de l'app, construits depuis un [ColorScheme] complet.
///
/// Avant, les couleurs étaient des constantes claires lues directement par les
/// widgets, ce qui rendait un thème sombre impossible. Ici tout passe par le
/// `ColorScheme` de Material et par [AppPalette] : les mêmes widgets rendent
/// correctement dans les deux thèmes.
class AppTheme {
  const AppTheme._();

  static const _fontFamily = 'Inter';

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF5A4FE0),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE8E5FD),
    onPrimaryContainer: Color(0xFF241C6B),
    secondary: Color(0xFF0E8F8F),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD6F3F3),
    onSecondaryContainer: Color(0xFF043B3B),
    tertiary: Color(0xFF9A6300),
    onTertiary: Color(0xFFFFFFFF),
    error: Color(0xFFC0311F),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFCE5E1),
    onErrorContainer: Color(0xFF48110A),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF151721),
    onSurfaceVariant: Color(0xFF656C7E),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAFBFD),
    surfaceContainer: Color(0xFFF5F6FA),
    surfaceContainerHigh: Color(0xFFF1F2F8),
    surfaceContainerHighest: Color(0xFFECEEF5),
    outline: Color(0xFFC9CDDA),
    outlineVariant: Color(0xFFE3E5EF),
    inverseSurface: Color(0xFF2A2E3A),
    onInverseSurface: Color(0xFFF3F4F8),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFADA5FF),
    onPrimary: Color(0xFF221A66),
    primaryContainer: Color(0xFF37317A),
    onPrimaryContainer: Color(0xFFE8E5FD),
    secondary: Color(0xFF55D4D4),
    onSecondary: Color(0xFF013535),
    secondaryContainer: Color(0xFF0B4E4E),
    onSecondaryContainer: Color(0xFFD6F3F3),
    tertiary: Color(0xFFF0B542),
    onTertiary: Color(0xFF2A1C00),
    error: Color(0xFFF28B7D),
    onError: Color(0xFF4A1008),
    errorContainer: Color(0xFF6B1D12),
    onErrorContainer: Color(0xFFFCE5E1),
    surface: Color(0xFF171A21),
    onSurface: Color(0xFFE9EBF0),
    onSurfaceVariant: Color(0xFF98A0AF),
    surfaceContainerLowest: Color(0xFF0E1014),
    surfaceContainerLow: Color(0xFF14171D),
    surfaceContainer: Color(0xFF1B1F26),
    surfaceContainerHigh: Color(0xFF22262F),
    surfaceContainerHighest: Color(0xFF2A2F39),
    outline: Color(0xFF4A5160),
    outlineVariant: Color(0xFF2D323C),
    inverseSurface: Color(0xFFE9EBF0),
    onInverseSurface: Color(0xFF1B1F26),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData get light =>
      _build(_lightScheme, AppPalette.light, const Color(0xFFF7F8FC));

  static ThemeData get dark =>
      _build(_darkScheme, AppPalette.dark, const Color(0xFF0E1014));

  static ThemeData _build(
    ColorScheme scheme,
    AppPalette palette,
    Color scaffoldBackground,
  ) {
    final isLight = scheme.brightness == Brightness.light;

    final textTheme = TextTheme(
      displaySmall: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15, color: scheme.onSurface),
      headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.2, color: scheme.onSurface),
      headlineSmall: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.25, color: scheme.onSurface),
      titleLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: scheme.onSurface),
      titleMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
      titleSmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
      bodyLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: scheme.onSurface),
      bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: scheme.onSurfaceVariant),
      bodySmall: TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.4, color: palette.textMuted),
      labelLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
      labelMedium: TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
      labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: palette.textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      extensions: [palette],
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: palette.sunken,
          disabledForegroundColor: palette.textMuted,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(
              fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(
              fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
              fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.sunken,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.sunken,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: palette.border),
        labelStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
            fontFamily: _fontFamily, fontSize: 14, color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        iconColor: scheme.onSurfaceVariant,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Par défaut, Material 3 teinte l'indicateur avec la couleur
        // secondaire — ici le turquoise, qui jurait avec le violet de la
        // marque juste au-dessus.
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? scheme.onPrimaryContainer
                  : palette.textMuted,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: _fontFamily,
              fontSize: 12,
              fontWeight:
                  states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? scheme.onSurface
                  : palette.textMuted,
            )),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: palette.textMuted),
        selectedLabelTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface),
        unselectedLabelTextStyle: TextStyle(
            fontFamily: _fontFamily, fontSize: 12, color: palette.textMuted),
      ),

      dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: palette.sunken,
        circularTrackColor: palette.sunken,
      ),

      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    );
  }
}
