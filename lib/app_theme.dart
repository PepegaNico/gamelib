import 'package:flutter/material.dart';

/// GameZer's slice of the shared "Zer Apps" design system — same base
/// palette, typography and component shapes as DriveZer/QuizZer/PulseZer,
/// with GameZer's own violet accent. Touching this cascades to every
/// screen, since nothing here is screen-specific.
const zerAccent = Color(0xFFA866FF);
const zerBackground = Color(0xFF050506);
const zerSurface = Color(0xFF0D0D10);
const zerSurfaceHigh = Color(0xFF17171B);
const zerTextPrimary = Color(0xFFF5F5F4);
const zerTextSecondary = Color(0xFF9A9A9F);
const zerDivider = Color(0x17F5F5F4); // rgba(245,245,244,.09)
const zerCardBorder = Color(0x0FF5F5F4); // rgba(245,245,244,.06)

/// Text color on top of an accent-filled surface (button, badge). The
/// accent is a mid-light violet, and WCAG contrast against it comes out
/// higher with near-black text than with white — see the "Buttons
/// (primär)" contrast rule in the design brief.
const zerOnAccent = Color(0xFF050506);

const _fontDisplay = 'Bricolage Grotesque';
const _fontBody = 'Instrument Sans';

/// For numeric/data readouts (playtime, prices) — apply explicitly via
/// this TextStyle where those values are rendered, there's no single
/// ThemeData slot for a third font family.
const zerMonoTextStyle = TextStyle(
  fontFamily: 'IBM Plex Mono',
  fontFeatures: [FontFeature.tabularFigures()],
);

ThemeData buildAppTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: zerAccent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: zerAccent,
        onPrimary: zerOnAccent,
        surface: zerBackground,
        onSurface: zerTextPrimary,
        surfaceContainerLowest: zerBackground,
        surfaceContainerLow: zerSurface,
        surfaceContainer: zerSurface,
        surfaceContainerHigh: zerSurfaceHigh,
        surfaceContainerHighest: zerSurfaceHigh,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: zerBackground,
    visualDensity: VisualDensity.comfortable,
    fontFamily: _fontBody,

    appBarTheme: const AppBarTheme(
      backgroundColor: zerBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // Page headers match the library's big "Bibliothek" title.
      toolbarHeight: 76,
      titleSpacing: 28,
      titleTextStyle: TextStyle(
        fontFamily: _fontDisplay,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: zerTextPrimary,
      ),
    ),

    cardTheme: CardThemeData(
      color: zerSurface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: zerCardBorder),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: zerSurfaceHigh,
      selectedColor: zerAccent.withValues(alpha: 0.35),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      labelStyle: const TextStyle(
        fontFamily: _fontBody,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: zerSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: zerAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: zerAccent,
        foregroundColor: zerOnAccent,
        textStyle: const TextStyle(
          fontFamily: _fontBody,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: zerAccent,
        textStyle: const TextStyle(
          fontFamily: _fontBody,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        side: const BorderSide(color: zerAccent, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: zerAccent,
        textStyle: const TextStyle(
          fontFamily: _fontBody,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: zerBackground,
      indicatorColor: zerAccent.withValues(alpha: 0.18),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      selectedIconTheme: const IconThemeData(color: zerAccent),
      unselectedIconTheme: const IconThemeData(color: zerTextSecondary),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: _fontBody,
        color: zerAccent,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: _fontBody,
        color: zerTextSecondary,
        fontSize: 12,
      ),
    ),

    dividerTheme: const DividerThemeData(color: zerDivider, space: 1),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: zerSurfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        fontFamily: _fontBody,
        color: zerTextPrimary,
        fontSize: 12,
      ),
    ),

    textTheme: ThemeData(brightness: Brightness.dark).textTheme
        .apply(
          fontFamily: _fontBody,
          bodyColor: zerTextPrimary.withValues(alpha: 0.92),
          displayColor: zerTextPrimary,
        )
        .copyWith(
          displayLarge: const TextStyle(
            fontFamily: _fontDisplay,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          headlineSmall: const TextStyle(
            fontFamily: _fontDisplay,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          titleLarge: const TextStyle(
            fontFamily: _fontDisplay,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: const TextStyle(
            fontFamily: _fontDisplay,
            fontWeight: FontWeight.w700,
          ),
        ),
  );
}
