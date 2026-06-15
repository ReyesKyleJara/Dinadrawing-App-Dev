import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────
  // BRAND COLORS
  // ─────────────────────────────────────────────

  static const Color brandYellow = Color(0xFFE8B653);
  static const Color brandYellowDark = Color(0xFFD79A2F);
  static const Color brandYellowSoft = Color(0xFFFFF3D7);

  // ─────────────────────────────────────────────
  // LIGHT COLORS
  // ─────────────────────────────────────────────

  static const Color lightScaffold = Color(0xFFF9F9FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSoft = Color(0xFFF3F3F5);
  static const Color lightTextPrimary = Color(0xFF1B1B1F);
  static const Color lightTextSecondary = Color(0xFF707078);
  static const Color lightDivider = Color(0xFFE8E7EA);
  static const Color lightOutline = Color(0xFFD8D6DB);

  // ─────────────────────────────────────────────
  // DARK COLORS
  // ─────────────────────────────────────────────

  static const Color darkScaffold = Color(0xFF141416);
  static const Color darkSurface = Color(0xFF1D1D20);
  static const Color darkSurfaceSoft = Color(0xFF27272B);
  static const Color darkSurfaceElevated = Color(0xFF303035);
  static const Color darkTextPrimary = Color(0xFFF4F2ED);
  static const Color darkTextSecondary = Color(0xFFB7B4AE);
  static const Color darkDivider = Color(0xFF38383E);
  static const Color darkOutline = Color(0xFF4A494F);

  // ─────────────────────────────────────────────
  // THEMES
  // ─────────────────────────────────────────────

  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      scaffoldColor: lightScaffold,
      surfaceColor: lightSurface,
      surfaceSoftColor: lightSurfaceSoft,
      elevatedSurfaceColor: lightSurface,
      primaryTextColor: lightTextPrimary,
      secondaryTextColor: lightTextSecondary,
      dividerColor: lightDivider,
      outlineColor: lightOutline,
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      scaffoldColor: darkScaffold,
      surfaceColor: darkSurface,
      surfaceSoftColor: darkSurfaceSoft,
      elevatedSurfaceColor: darkSurfaceElevated,
      primaryTextColor: darkTextPrimary,
      secondaryTextColor: darkTextSecondary,
      dividerColor: darkDivider,
      outlineColor: darkOutline,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldColor,
    required Color surfaceColor,
    required Color surfaceSoftColor,
    required Color elevatedSurfaceColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color dividerColor,
    required Color outlineColor,
  }) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: brandYellow,
          brightness: brightness,
        ).copyWith(
          primary: brandYellow,
          onPrimary: Colors.black,
          primaryContainer: isDark ? const Color(0xFF5A431C) : brandYellowSoft,
          onPrimaryContainer: isDark
              ? const Color(0xFFFFE3A6)
              : const Color(0xFF4D3400),
          secondary: brandYellowDark,
          onSecondary: Colors.black,
          surface: surfaceColor,
          onSurface: primaryTextColor,
          surfaceContainerHighest: surfaceSoftColor,
          onSurfaceVariant: secondaryTextColor,
          outline: outlineColor,
          outlineVariant: dividerColor,
          error: const Color(0xFFD84A4A),
          onError: Colors.white,
        );

    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: scaffoldColor,
      canvasColor: scaffoldColor,
      cardColor: surfaceColor,
      dividerColor: dividerColor,
      disabledColor: secondaryTextColor.withValues(alpha: 0.45),
      splashColor: brandYellow.withValues(alpha: 0.10),
      highlightColor: brandYellow.withValues(alpha: 0.06),
      hoverColor: brandYellow.withValues(alpha: 0.06),

      // ─────────────────────────────────────────
      // TYPOGRAPHY
      // ─────────────────────────────────────────
      textTheme: baseTheme.textTheme
          .apply(bodyColor: primaryTextColor, displayColor: primaryTextColor)
          .copyWith(
            displayLarge: TextStyle(
              color: primaryTextColor,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
            displayMedium: TextStyle(
              color: primaryTextColor,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
            headlineLarge: TextStyle(
              color: primaryTextColor,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
            headlineMedium: TextStyle(
              color: primaryTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            titleLarge: TextStyle(
              color: primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            titleMedium: TextStyle(
              color: primaryTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            titleSmall: TextStyle(
              color: primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            bodyLarge: TextStyle(
              color: primaryTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            bodyMedium: TextStyle(
              color: primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            bodySmall: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
            labelLarge: TextStyle(
              color: primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            labelMedium: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            labelSmall: TextStyle(
              color: secondaryTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

      // ─────────────────────────────────────────
      // APP BAR
      // ─────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldColor,
        foregroundColor: primaryTextColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryTextColor, size: 22),
        actionsIconTheme: IconThemeData(color: primaryTextColor, size: 22),
        titleTextStyle: TextStyle(
          color: primaryTextColor,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),

      // ─────────────────────────────────────────
      // INPUT FIELDS
      // ─────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoftColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          color: secondaryTextColor.withValues(alpha: 0.72),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(
          color: secondaryTextColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: brandYellowDark,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: secondaryTextColor,
        suffixIconColor: secondaryTextColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineColor.withValues(alpha: 0.30)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandYellow, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD84A4A), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD84A4A), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),

      // ─────────────────────────────────────────
      // PRIMARY BUTTONS
      // ─────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandYellow,
          foregroundColor: Colors.black,
          disabledBackgroundColor: secondaryTextColor.withValues(alpha: 0.24),
          disabledForegroundColor: secondaryTextColor.withValues(alpha: 0.72),
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTextColor,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: dividerColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandYellowDark,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      // ─────────────────────────────────────────
      // SWITCHES
      // ─────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.disabled)) {
            return secondaryTextColor.withValues(alpha: 0.45);
          }

          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }

          return isDark ? const Color(0xFFB4B1AB) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.disabled)) {
            return dividerColor;
          }

          if (states.contains(WidgetState.selected)) {
            return brandYellow;
          }

          return isDark ? const Color(0xFF444449) : const Color(0xFFD5D3D8);
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),

      // ─────────────────────────────────────────
      // LIST TILES
      // ─────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        iconColor: primaryTextColor,
        textColor: primaryTextColor,
        contentPadding: EdgeInsets.zero,
        titleTextStyle: TextStyle(
          color: primaryTextColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ─────────────────────────────────────────
      // BOTTOM NAVIGATION
      // ─────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: brandYellowDark,
        unselectedItemColor: secondaryTextColor,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: brandYellow.withValues(alpha: 0.22),
        elevation: 4,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final selected = states.contains(WidgetState.selected);

          return TextStyle(
            color: selected ? primaryTextColor : secondaryTextColor,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final selected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected ? brandYellowDark : secondaryTextColor,
            size: 22,
          );
        }),
      ),

      // ─────────────────────────────────────────
      // DIALOGS, SHEETS, MENUS
      // ─────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        modalBackgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        modalElevation: 12,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: elevatedSurfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        textStyle: TextStyle(
          color: primaryTextColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // ─────────────────────────────────────────
      // SNACKBARS
      // ─────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFFF1EEE7)
            : const Color(0xFF252529),
        contentTextStyle: TextStyle(
          color: isDark ? const Color(0xFF202024) : Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: brandYellow,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ─────────────────────────────────────────
      // DIVIDERS AND PROGRESS
      // ─────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandYellow,
        linearTrackColor: Colors.transparent,
      ),

      iconTheme: IconThemeData(color: primaryTextColor, size: 22),

      primaryIconTheme: IconThemeData(color: primaryTextColor, size: 22),
    );
  }
}
