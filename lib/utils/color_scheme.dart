import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoThemeData;
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
  final defaultPalette = seedColor == const Color(0xFF197D74) ||
      seedColor == const Color(0xFF56674F);
  // Preserve the existing dark palette while refreshing the default light theme.
  if (defaultPalette) {
    seedColor = isDark ? const Color(0xFF56674F) : const Color(0xFF197D74);
  }
  const einkBackground = Colors.white;
  const einkForeground = Colors.black;
  final disableMotion = prefsNotifier.eInkMotionDisabled;

  final lightGropedBackground = const Color(0xFFFCFCFA);
  final darkGropedBackground =
      prefsNotifier.trueDarkMode ? Color(0xFF000000) : Color(0xFF1C1E1B);
  final gropedBackgroundColor = isEinkMode
      ? einkBackground
      : isDark
          ? darkGropedBackground
          : lightGropedBackground;

  var colorScheme = isEinkMode
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
              surfaceContainer: lightGropedBackground,
              surface: lightGropedBackground,
            ),
          Brightness.dark => ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.dark,
              surfaceContainer: darkGropedBackground,
              surface: darkGropedBackground,
            ),
        };
  if (!isEinkMode) {
    final ink = isDark ? const Color(0xFFE5E7DF) : const Color(0xFF283633);
    final accent = isDark ? const Color(0xFFB5C4A7) : const Color(0xFF197D74);
    final selected = isDark ? const Color(0xFF303A2B) : const Color(0xFFE5F3EE);
    colorScheme = colorScheme.copyWith(
      primary: defaultPalette ? accent : null,
      onPrimary: defaultPalette
          ? (isDark ? const Color(0xFF263120) : const Color(0xFFFFFFFF))
          : null,
      primaryContainer: defaultPalette ? selected : null,
      onPrimaryContainer: defaultPalette ? ink : null,
      secondary: defaultPalette ? accent : null,
      onSecondary: defaultPalette
          ? (isDark ? const Color(0xFF263120) : const Color(0xFFFFFFFF))
          : null,
      secondaryContainer: defaultPalette ? selected : null,
      onSecondaryContainer: defaultPalette ? ink : null,
      tertiary: defaultPalette ? accent : null,
      tertiaryContainer: defaultPalette ? selected : null,
      onTertiaryContainer: defaultPalette ? ink : null,
      onSurface: ink,
      onSurfaceVariant:
          isDark ? const Color(0xFFA2A79B) : const Color(0xFF65716D),
      surfaceContainerLowest: gropedBackgroundColor,
      surfaceContainerLow: gropedBackgroundColor,
      surfaceContainerHigh: gropedBackgroundColor,
      surfaceContainerHighest: gropedBackgroundColor,
      surfaceDim: gropedBackgroundColor,
      surfaceBright: gropedBackgroundColor,
      surfaceTint: Colors.transparent,
      outline: isDark ? const Color(0xFF777E70) : const Color(0xFF899A93),
      outlineVariant:
          isDark ? const Color(0xFF383D35) : const Color(0xFFE4EAE6),
    );
  }

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

  final menuBorder = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: colorScheme.outlineVariant),
  );
  final menuElevation = isEinkMode ? 0.0 : 4.0;
  final menuShadow =
      isEinkMode ? Colors.transparent : Colors.black.withValues(alpha: 0.20);
  final einkButton = ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: const WidgetStatePropertyAll(einkForeground),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    side: const WidgetStatePropertyAll(BorderSide(color: einkForeground)),
  );

  return themeData
      .copyWith(
          canvasColor: gropedBackgroundColor,
          navigationRailTheme: themeData.navigationRailTheme.copyWith(
            backgroundColor: gropedBackgroundColor,
          ),
          navigationBarTheme: themeData.navigationBarTheme.copyWith(
            backgroundColor: gropedBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
          bottomNavigationBarTheme: themeData.bottomNavigationBarTheme.copyWith(
            backgroundColor: gropedBackgroundColor,
          ),
          cupertinoOverrideTheme: CupertinoThemeData(
            brightness: brightness,
            primaryColor: colorScheme.primary,
            scaffoldBackgroundColor: gropedBackgroundColor,
            barBackgroundColor: gropedBackgroundColor,
          ),
          cardTheme: CardThemeData(
            color: isEinkMode ? Colors.transparent : gropedBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: menuElevation,
            shadowColor: menuShadow,
            shape: menuBorder,
            clipBehavior: Clip.antiAlias,
          ),
          appBarTheme: themeData.appBarTheme.copyWith(
            backgroundColor: gropedBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: gropedBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: menuElevation,
            shadowColor: menuShadow,
            shape: menuBorder,
          ),
          menuTheme: MenuThemeData(
              style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(gropedBackgroundColor),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: WidgetStatePropertyAll(menuElevation),
            shadowColor: WidgetStatePropertyAll(menuShadow),
            shape: WidgetStatePropertyAll(menuBorder),
          )),
          chipTheme: isEinkMode
              ? themeData.chipTheme.copyWith(
                  color: const WidgetStatePropertyAll(Colors.transparent),
                  backgroundColor: Colors.transparent,
                  selectedColor: Colors.transparent,
                  disabledColor: Colors.transparent,
                  checkmarkColor: einkForeground,
                  side: const BorderSide(color: einkForeground),
                  labelStyle: themeData.textTheme.labelLarge
                      ?.copyWith(color: einkForeground),
                )
              : themeData.chipTheme,
          segmentedButtonTheme: isEinkMode
              ? SegmentedButtonThemeData(style: einkButton)
              : themeData.segmentedButtonTheme,
          filledButtonTheme: isEinkMode
              ? FilledButtonThemeData(style: einkButton)
              : themeData.filledButtonTheme,
          elevatedButtonTheme: isEinkMode
              ? ElevatedButtonThemeData(style: einkButton)
              : themeData.elevatedButtonTheme,
          iconButtonTheme: isEinkMode
              ? const IconButtonThemeData(
                  style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                  foregroundColor: WidgetStatePropertyAll(einkForeground),
                ))
              : themeData.iconButtonTheme,
          switchTheme: isEinkMode
              ? const SwitchThemeData(
                  trackColor: WidgetStatePropertyAll(Colors.transparent),
                  trackOutlineColor: WidgetStatePropertyAll(einkForeground),
                  thumbColor: WidgetStatePropertyAll(einkForeground),
                )
              : themeData.switchTheme,
          checkboxTheme: isEinkMode
              ? const CheckboxThemeData(
                  fillColor: WidgetStatePropertyAll(Colors.transparent),
                  checkColor: WidgetStatePropertyAll(einkForeground),
                  side: BorderSide(color: einkForeground),
                )
              : themeData.checkboxTheme,
          inputDecorationTheme: themeData.inputDecorationTheme.copyWith(
            filled: false,
            fillColor: Colors.transparent,
          ),
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
          sliderTheme: SliderThemeData(
            // Flutter still requires this deprecated opt-in for the 2024 shapes.
            // ignore: deprecated_member_use
            year2023: false,
            thumbSize:
                isEinkMode ? null : const WidgetStatePropertyAll(Size(4, 28)),
            allowedInteraction: SliderInteraction.slideThumb,
          ),
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
                (isEinkMode ? einkBackground : colorScheme.surfaceContainer)
                    .withValues(alpha: .5),
            elevation: 0,
            contentTextStyle: themeData.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurface),
            actionTextColor: colorScheme.primary,
            closeIconColor: colorScheme.onSurface,
            insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          ),
          bottomSheetTheme: BottomSheetThemeData(
              clipBehavior: Clip.antiAlias,
              backgroundColor: gropedBackgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: menuElevation,
              shadowColor: menuShadow,
              shape: RoundedRectangleBorder(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                side: BorderSide(color: colorScheme.outlineVariant),
              )),
          drawerTheme: DrawerThemeData()
              .copyWith(backgroundColor: gropedBackgroundColor),
          dialogTheme: DialogThemeData(
              clipBehavior: Clip.antiAlias,
              backgroundColor: gropedBackgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: menuElevation,
              shadowColor: menuShadow,
              shape: menuBorder))
      .useSystemChineseFont(brightness);
}
