# Harmony reader toolbar cutout adaptation

Scope: only the HarmonyOS reader top toolbar, in the current 1.3.2 checkout.
The supplied photo shows the leftmost Harmony device's title/controls overlapping
the camera notch while the reader hides system bars. The existing AppBar relies
on Flutter MediaQuery padding, which is insufficient in this reported state.

The OHOS-only ReaderCutoutPlugin reads Window.getWindowAvoidArea(TYPE_CUTOUT)
from the attached ability window, independently of the hidden system status bar.
It returns physical edge exclusions (including a cutout's offset from the edge).
HarmonyReaderToolbar converts these with the Flutter view's pixel ratio and
merges by maximum into the AppBar subtree's padding. It refreshes on metrics,
resume and parent updates and discards stale asynchronous responses. The reading
surface, pagination, bottom controls and other platforms retain their layout.

Reference: https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-arkui/arkts-apis-window-Window.md

Checks:

- `node --test test/reader_harmony_cutout.test.mjs`: four native bridge fixture tests passed (not an ArkTS compiler).
- `flutter test test/widgets/harmony_reader_toolbar_test.dart test/widgets/reader_top_actions_test.dart`: 13 tests passed, covering immersive notch clearance, pixel conversion, unchanged non-Harmony layout, no duplicate safe-area spacing, rotation and stale results, plus existing toolbar behavior.

Not performed: signed HAP build or physical Harmony device verification. On the
reported phone, verify the title, Back and action buttons below the notch with
status bars hidden/shown, reopen the toolbar, rotate both directions and return
from background. A no-cutout window must not gain a fixed blank top strip.
