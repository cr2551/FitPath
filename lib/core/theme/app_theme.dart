import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'app_typography.dart';
import 'fit_colors.dart';

/// The app's single source of visual style (DESIGN/README.md).
///
/// Convention for all feature code:
/// * never hard-code colors, radii, font sizes or font families;
/// * read `Theme.of(context)`, `context.fitColors` or `context.textStyles`;
/// * compose `lib/shared/widgets/` instead of restyling widgets per screen.
///
/// Rules: no gradients, no shadows (elevation 0 everywhere), radii of at most
/// 8 px (no pill shapes), no pastel tints.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, FitColors.light);

  static ThemeData get dark => _build(Brightness.dark, FitColors.dark);

  /// Style for the one most important action on a screen (e.g. "Log food"):
  /// açaí fill. Use with `FilledButton(style: AppTheme.accentButton(context))`.
  static ButtonStyle accentButton(BuildContext context) {
    final c = context.fitColors;
    return FilledButton.styleFrom(
      backgroundColor: c.accent,
      foregroundColor: c.onAccent,
    );
  }

  static const _smShape = RoundedRectangleBorder(borderRadius: AppRadii.smAll);

  static ThemeData _build(Brightness brightness, FitColors c) {
    final text = FitTextStyles.of(c);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.surface,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.error,
      onError: c.surface,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.subtle,
      surfaceContainerHigh: c.subtle,
      surfaceContainerHighest: c.subtle,
      outline: c.line,
      outlineVariant: c.line,
      surfaceTint: Colors.transparent,
      shadow: Colors.transparent,
    );

    final lineSide = BorderSide(color: c.line);
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.line,
      fontFamily: AppFonts.body,
      extensions: [c, text],
      textTheme: TextTheme(
        displayLarge: text.hero,
        displayMedium: text.display,
        headlineMedium: text.headline,
        titleLarge: text.cardTitle,
        titleMedium: text.bodyStrong,
        titleSmall: text.bodyStrong,
        bodyLarge: text.body,
        bodyMedium: text.body,
        bodySmall: text.label,
        labelLarge: text.button,
        labelMedium: text.label,
        labelSmall: text.overline,
      ),
      iconTheme: IconThemeData(color: c.ink, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: text.headline,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: lineSide,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.surface,
          minimumSize: const Size(0, 48),
          shape: _smShape,
          elevation: 0,
          textStyle: AppTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(0, 48),
          shape: _smShape,
          side: BorderSide(color: c.ink, width: 1.5),
          textStyle: AppTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          shape: _smShape,
          textStyle: AppTypography.bodyStrong.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.ink,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: inputBorder(c.line),
        enabledBorder: inputBorder(c.line),
        focusedBorder: inputBorder(c.ink, 1.5),
        errorBorder: inputBorder(c.error),
        focusedErrorBorder: inputBorder(c.error, 1.5),
        hintStyle: text.body.copyWith(color: c.inkMuted),
        labelStyle: text.body.copyWith(color: c.inkMuted),
        errorStyle: text.label.copyWith(color: c.error),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        height: 70,
        surfaceTintColor: Colors.transparent,
        // Solid açaí rectangle instead of Material's pill indicator.
        indicatorColor: c.accent,
        indicatorShape: _smShape,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? c.onAccent : c.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.label.copyWith(
            color: s.contains(WidgetState.selected) ? c.ink : c.inkMuted,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(_smShape),
          side: WidgetStatePropertyAll(lineSide),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.ink : c.subtle,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.surface : c.inkMuted,
          ),
          textStyle: WidgetStatePropertyAll(
            AppTypography.overline.copyWith(fontSize: 15),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: _smShape,
        side: lineSide,
        backgroundColor: c.surface,
        selectedColor: c.ink,
        checkmarkColor: c.surface,
        // Material 3 ignores secondaryLabelStyle and resolves only the
        // label COLOR by state, so it must be a WidgetStateColor or ink text
        // sits on the ink fill of a selected chip.
        labelStyle: text.label.copyWith(
          color: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.surface : c.ink,
          ),
        ),
        secondaryLabelStyle: text.label.copyWith(color: c.surface),
        elevation: 0,
        pressElevation: 0,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          side: WidgetStatePropertyAll(lineSide),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadii.smAll),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.smAll,
          side: lineSide,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: lineSide,
        ),
        titleTextStyle: text.cardTitle,
        contentTextStyle: text.body,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        modalElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.md),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.body.copyWith(color: c.surface),
        actionTextColor: c.surface,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: _smShape,
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        titleTextStyle: text.bodyStrong,
        subtitleTextStyle: text.label,
        iconColor: c.inkMuted,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.ink,
        linearTrackColor: c.line,
        circularTrackColor: c.line,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.ink : null,
        ),
        checkColor: WidgetStatePropertyAll(c.surface),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.surface : c.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.ink : c.subtle,
        ),
      ),
    );
  }
}
