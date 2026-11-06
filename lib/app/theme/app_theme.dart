import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_tokens.dart';

class AdoetzAppTheme {
  const AdoetzAppTheme._();

  static ThemeData buildTheme(AdoetzPalette palette) {
    final brightness = palette.isDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.accentPrimary,
      onPrimary: palette.accentOnPrimary,
      secondary: palette.accentInteractive,
      onSecondary: palette.accentOnPrimary,
      error: palette.statusDanger,
      onError: Colors.white,
      surface: palette.bgSurface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.bgElevated,
      outline: palette.borderHairline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.bgCanvas,
      canvasColor: palette.bgCanvas,
      dividerColor: palette.borderHairline,
      splashFactory: InkRipple.splashFactory,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bgSurface,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: AdoetzDimensions.topAppBarHeight,
        titleTextStyle: AdoetzTypography.screenTitle(palette.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: palette.isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: palette.bgSurface,
          systemNavigationBarIconBrightness:
              palette.isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.borderHairline,
        thickness: 0.5,
        space: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.bgElevated,
        hintStyle: AdoetzTypography.listSubtitle(palette.textSecondary),
        labelStyle: AdoetzTypography.listSubtitle(palette.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdoetzDimensions.radiusButton),
          borderSide: BorderSide(color: palette.borderHairline, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdoetzDimensions.radiusButton),
          borderSide: BorderSide(color: palette.borderHairline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdoetzDimensions.radiusButton),
          borderSide: BorderSide(color: palette.accentPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdoetzDimensions.radiusButton),
          borderSide: BorderSide(color: palette.statusDanger, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accentPrimary,
          foregroundColor: palette.accentOnPrimary,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdoetzDimensions.radiusButton),
          ),
          textStyle: AdoetzTypography.buttonLabel(palette.accentOnPrimary),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: palette.borderHairline, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdoetzDimensions.radiusButton),
          ),
          textStyle: AdoetzTypography.buttonLabel(palette.textPrimary),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AdoetzDimensions.radiusSheetOrDialog),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdoetzDimensions.radiusSheetOrDialog),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.bgOverlay,
        contentTextStyle: AdoetzTypography.listSubtitle(palette.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdoetzDimensions.radiusButton),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AdoetzDimensions.bottomNavBarHeight,
        backgroundColor: palette.bgSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.accentSubtle,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12.0,
            height: 16.0 / 12.0,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? palette.accentInteractive : palette.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22.0,
            color: isSelected ? palette.accentInteractive : palette.textSecondary,
          );
        }),
      ),
    );
  }

  static ThemeData get darkTheme => buildTheme(AdoetzPalette.dark);
  static ThemeData get lightTheme => buildTheme(AdoetzPalette.light);
}
