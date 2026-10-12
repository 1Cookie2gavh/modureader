# Local toolchain (2026-10-11)

Use Flutter 3.47.2 / Dart 3.13.2, JDK 17, Android SDK 36 / Build Tools
36.0.0, Gradle 9.2.1, AGP 9.0.1 and Kotlin 2.3.20. Do not upgrade the
application's Riverpod runtime just to update lint tooling.

## Analysis

`analysis_options.yaml` loads the vendored Riverpod native analyzer plugin in an
isolated dependency context. See
[compatibility notes](../../third_party/riverpod_lint/README.modu.md).
Use `flutter analyze --no-pub` / `dart analyze`, not `dart run custom_lint`.
The application code generators remain on analyzer 7.3.0; 7.6.0 breaks their
legacy element APIs. This pin does not downgrade the isolated lint plugin.
Code generation still reports its older parser's SDK-language-version warning;
it completes successfully and produces unchanged output. Do not suppress this
warning or confuse the generator parser with the SDK/native lint analyzer.
Run `node --test test/tooling_lint_compatibility.test.mjs` to verify that a
Riverpod 2 annotation still triggers the context-safety rule. This test creates
and removes only its own uniquely named temporary source file.

Release staging directories and archived QA copies are excluded, not application
source or tests. Windows vendor callback forwarding retains narrow, documented
exceptions for legacy callback deprecations and platform parameter covariance.
The Flutter `year2023: false` exceptions retain the current 2024 control design;
the installed SDK still requires that deprecated opt-in.

## Flutter analysis with Chinese workspace paths

Flutter 3.47.2's `packages/flutter_tools/lib/src/dart/analysis.dart` sends LSP
`Content-Length` using a Dart string's UTF-16 length, not its UTF-8 byte length.
Chinese workspace names therefore truncate requests and crash analysis.
The local SDK fix is:

```dart
_process?.stdin.write('Content-Length: ${utf8.encode(message).length}\r\n\r\n$message');
```

The original source and tool snapshot are preserved with the suffix
`.modu-backup-20261011`. The snapshot was regenerated after applying the fix.
An SDK reinstall may overwrite this local fix; check the line above before
reapplying it. Do not remove the entire SDK cache.

## Local development tools

Flutter already selects `/opt/homebrew/opt/openjdk@17`. `adb` and `fastboot` in
`/opt/homebrew/bin` now link to the SDK's `platform-tools`; original links are
backed up with `.modu-backup-20261011`. Homebrew updates may replace those links.

The complete Xcode 26.6 installation passes checks with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter doctor -v
JAVA_HOME=/opt/homebrew/opt/openjdk@17 android/gradlew -p android help --offline --warning-mode all
```

The system-wide `xcode-select` change requires administrator authentication; it
was not applied without that authentication. To select Xcode permanently:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Some Android SDK licenses remain unaccepted. Review them interactively using
`flutter doctor --android-licenses`; do not silently accept new license terms.

`android.newDsl=false` remains necessary for this Flutter version. AGP 9 reports
its planned removal in AGP 10; removing the flag or upgrading AGP alone is unsafe.
The configuration-only check does not reproduce the earlier SDK XML warning or
execute Flutter's release task, so it cannot prove those full-build warnings
are gone. Recheck them during the next requested package build.
