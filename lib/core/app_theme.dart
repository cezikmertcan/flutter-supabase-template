import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const background = Color(0xFF07100D);
  static const surface = Color(0xFF0D1A14);
  static const surfaceElevated = Color(0xFF11241A);
  static const primary = Color(0xFF7DFF9E);
  static const secondary = Color(0xFFC7FF73);
  static const ink = Color(0xFFE7F4EA);
  static const muted = Color(0xFF8CA99A);
  static const line = Color(0xFF234333);
  static const warning = Color(0xFFFFD27A);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    const seedColor = primary;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        ).copyWith(
          primary: brightness == Brightness.dark
              ? primary
              : const Color(0xFF167A3B),
          onPrimary: brightness == Brightness.dark ? background : Colors.white,
          secondary: brightness == Brightness.dark
              ? secondary
              : const Color(0xFF4E7F21),
          surface: brightness == Brightness.dark
              ? surface
              : const Color(0xFFF8FBF8),
          onSurface: brightness == Brightness.dark
              ? ink
              : const Color(0xFF122219),
          outline: brightness == Brightness.dark
              ? line
              : const Color(0xFFC6D7CB),
        );
    final isLight = brightness == Brightness.light;
    final baseText = ThemeData(brightness: brightness).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isLight ? const Color(0xFFF3F8F4) : background,
      textTheme: baseText.copyWith(
        bodyLarge: baseText.bodyLarge?.copyWith(
          color: colorScheme.onSurface,
          height: 1.45,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: isLight ? const Color(0xFF587064) : muted,
          height: 1.4,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.0,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
        labelSmall: baseText.labelSmall?.copyWith(
          color: isLight ? const Color(0xFF397252) : primary,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isLight ? Colors.white : surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
        hintStyle: TextStyle(color: isLight ? const Color(0xFF759183) : muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? Colors.white : const Color(0xFF09150F),
        indicatorColor: isLight
            ? const Color(0xFFD5F5DE)
            : const Color(0xFF174D2C),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          baseText.labelSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? const Color(0xFF173725) : surfaceElevated,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
