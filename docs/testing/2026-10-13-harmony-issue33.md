# HarmonyOS #33 — partial fixes, not device acceptance

Evidence: issue #33 by `xuezeyang123-hub`, user-supplied 36-second video and
2026-10-12 log screenshot. Shelf controls work and tapping an invisible book
starts a cover transition, then the reader reports chapter load failure.
The screenshot's `wakelock_plus` channel error occurs **after** the reading
page's successful pop. It does not establish the cause of either visible bug.

## Changes

- Reader enable, timeout and exit use a shared ordered bridge. HarmonyOS uses
  `modu/reader_wakelock` → `setWindowKeepScreenOn`; other targets retain
  wakelock_plus. Failures are caught, and native detachment releases the window.
- File export validates against `FlutterPluginBinding.getApplicationContext()`'s
  cache, matching the pinned path_provider plugin, not UIAbilityContext.cacheDir.
  UIAbilityContext is still used for the document picker. No broader filesystem
  permission, source deletion, automatic export or upload is introduced.
- Upstream source inspected at CPF-Flutter/flutter_packages commit
  `d4e49daa0acbd0bc419d58b1da27d64d44fab54b`,
  `packages/path_provider/path_provider_ohos/ohos/src/main/ets/io/flutter/plugins/pathprovider/PathProviderPlugin.ets`:
  `setup()` uses the engine application context; `getTemporaryPath()` returns
  that context's `cacheDir`. Application and ability contexts must not be assumed
  to have identical cache paths.

## Local regression checks

```sh
node --test test/harmony_file_export.test.mjs test/harmony_reader_wakelock.test.mjs
flutter test --no-pub test/utils/reader_wakelock_test.dart test/utils/harmony_file_export_test.dart test/widgets/log_page_test.dart --reporter expanded
flutter analyze --no-pub
```

Native handler tests execute the actual ETS method bodies after stripping types,
with mocked window/file APIs. They check enable/release, detachment, channel
failure recovery, different context cache paths, rejected paths, cancellation,
closed handles and preservation of original logs. They are **not** ArkTS type
checking, native integration tests or proof of device behavior.

Results on 2026-10-13: 15 native-handler mock tests and 12 Flutter tests passed;
`flutter analyze --no-pub` reported no issues. `git diff --check` passed.

## Still required

No HarmonyOS device or SDK compiler is connected locally. On a device, verify
open → timeout → exit does not leave screen-on state, export and cancellation
retain the source log, and collect the earlier Flutter/WebView failure records.
Do not close #33 or claim the blank shelf / chapter failure has been fixed based
on these two partial fixes. No HAP/APK build or publication is included.
