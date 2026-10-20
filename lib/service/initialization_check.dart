import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/version_check_type.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/utils/app_version.dart';
import 'package:flutter/cupertino.dart';
import 'package:anx_reader/page/changelog_screen.dart';
import 'package:anx_reader/utils/log/common.dart';

class InitializationCheck {
  static String? _lastVersion;
  static String? _currentVersion;

  static Future<String> get lastVersion async {
    if (_lastVersion == null) {
      await _checkVersion();
    }
    return _lastVersion!;
  }

  static Future<String> get currentVersion async {
    if (_currentVersion == null) {
      await _checkVersion();
    }
    return _currentVersion!;
  }

  static Future<void> check() async {
    final result = await _checkVersion();
    AnxLog.info('Version check result: $result');
    if (result == VersionCheckType.firstLaunch) {
      Prefs().lastAppVersion = _currentVersion;
      _handleNormalStartup();
    } else if (result == VersionCheckType.updated) {
      _handleUpdateAvailable();
    } else {
      _handleNormalStartup();
    }
  }

  static Future<VersionCheckType> _checkVersion() async {
    _lastVersion = Prefs().lastAppVersion;
    _currentVersion = await getAppVersion();
    if (_lastVersion == null) {
      return VersionCheckType.firstLaunch;
    } else {
      if (_lastVersion != _currentVersion) {
        return VersionCheckType.updated;
      } else {
        return VersionCheckType.normal;
      }
    }
  }

  static Future<void> _handleUpdateAvailable() async {
    final lv = await lastVersion;
    final cv = await currentVersion;
    AnxLog.info('Version update detected: $lv -> $cv');
    Future.delayed(const Duration(milliseconds: 800), () {
      showCupertinoSheet(
        context: navigatorKey.currentContext!,
        scrollableBuilder: (BuildContext context, ScrollController controller) {
          Widget widgetBuilder(BuildContext context) => ChangelogScreen(
                lastVersion: lv,
                currentVersion: cv,
                onComplete: () {
                  Prefs().lastAppVersion = cv;
                  Navigator.pop(context);
                },
              );
          return widgetBuilder(context);
        },
      );
    });
  }

  static void _handleNormalStartup() {
    AnxLog.info('Normal startup, proceeding to main app');
  }
}
