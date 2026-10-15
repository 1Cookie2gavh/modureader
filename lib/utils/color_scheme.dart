import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:anx_reader/utils/app_motion.dart';

ThemeData colorSchema(
  Prefs prefsNotifier,
  BuildContext context,
  Brightness brightness,
) {
  brightness = prefsNotifier.eInkMode
      ? Brightness.light
      : switch (prefsNotifier.themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
  Color seedColor = prefsNotifier.themeColor;
  final isDark = brightness == Brightness.dark;
  final isEinkMode = prefsNotifier.eInkMode;
  const einkBackground = Colors.white;
  const einkForeground = Colors.black;
  final disableMotion = prefsNotifier.eInkMotionDisabled;

  final lightGropedBackground = const Color(0xFFF2F2F7);
  final darkGropedBackground =
      prefsNotifier.trueDarkMode ? Color(0xFF000000) : Color(0xFF1C1C1E);
  final gropedBackgroundColor = isEinkMode
      ? einkBackground
      : isDark
          ? darkGropedBackground
          : lightGropedBackground;

  final colorScheme = isEinkMode
      ? ColorScheme(
          brightness: brightness,
          primary: einkForeground,
          onPrimary: einkBackground,
          primaryContainer: einkBackground,
          onPrimaryContainer: einkForeground,
          secondary: einkForeground,
          onSecondary: einkBackground,
          secondaryContainer: einkBackground,
          onSecondaryContainer: einkForeground,
          tertiary: einkForeground,
          onTertiary: einkBackground,
          error: einkForeground,
          onError: einkBackground,
          surface: einkBackground,
          onSurface: einkForeground,
          onSurfaceVariant: einkForeground,
          surfaceContainer: einkBackground,
          surfaceContainerLowest: einkBackground,
          surfaceContainerLow: einkBackground,
          surfaceContainerHigh: einkBackground,
          surfaceContainerHighest: einkBackground,
          surfaceDim: einkBackground,
          surfaceBright: einkBackground,
          surfaceTint: Colors.transparent,
          outline: einkForeground,
          outlineVariant: einkForeground,
          inverseSurface: einkForeground,
          onInverseSurface: einkBackground,
          inversePrimary: einkBackground,
        )
      : switch (brightness) {
          Brightness.light => ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.light,
              surfaceContainer: Color(0xFFFFFFFF),
              surface: lightGropedBackground,
            ),
          Brightness.dark => ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.dark,
              surfaceContainer: Color(0xFF2C2C2E),
              surface: darkGropedBackground,
            ),
        };

  ThemeData themeData = switch (brightness) {
    Brightness.light => FlexThemeData.light(
        useMaterial3: true,
        swapLegacyOnMaterial3: true,
        colorScheme: colorScheme,
      ),
    Brightness.dark => FlexThemeData.dark(
        useMaterial3: true,
        swapLegacyOnMaterial3: true,
        darkIsTrueBlack: prefsNotifier.trueDarkMode,
        colorScheme: colorScheme,
      )
  };

  return themeData
      .copyWith(
          textTheme: isEinkMode
              ? themeData.textTheme.apply(
                  bodyColor: einkForeground, displayColor: einkForeground)
              : themeData.textTheme,
          pageTransitionsTheme: disableMotion
              ? PageTransitionsTheme(builders: {
                  for (final platform in TargetPlatform.values)
                    platform: const NoMotionPageTransitionsBuilder(),
                })
              : themeData.pageTransitionsTheme,
          splashFactory:
              disableMotion ? NoSplash.splashFactory : themeData.splashFactory,
          highlightColor:
              disableMotion ? Colors.transparent : themeData.highlightColor,
          hoverColor: disableMotion ? Colors.transparent : themeData.hoverColor,
          expansionTileTheme: themeData.expansionTileTheme
              .copyWith(expansionAnimationStyle: AppMotion.style),
          // Flutter still requires this deprecated opt-in for the 2024 shapes.
          // ignore: deprecated_member_use
          sliderTheme: const SliderThemeData(year2023: false),
          progressIndicatorTheme:
              // ignore: deprecated_member_use
              const ProgressIndicatorThemeData(year2023: false),
          scaffoldBackgroundColor: gropedBackgroundColor,
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: StadiumBorder(
                side: isEinkMode
                    ? BorderSide(color: einkForeground)
                    : BorderSide.none),
            backgroundColor:
                isEinkMode ? einkBackground : colorScheme.surfaceContainer,
            contentTextStyle: themeData.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurface),
            actionTextColor: colorScheme.primary,
            closeIconColor: colorScheme.onSurface,
            insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          ),
          bottomSheetTheme: BottomSheetThemeData()
              .copyWith(backgroundColor: gropedBackgroundColor),
          drawerTheme: DrawerThemeData()
              .copyWith(backgroundColor: gropedBackgroundColor),
          dialogTheme: DialogThemeData()
              .copyWith(backgroundColor: gropedBackgroundColor))
      .useSystemChineseFont(brightness);
}
