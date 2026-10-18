# E-Ink reader investigation, 2026-10-16

## Evidence and limits

The device is attached to the user's other computer, not this Mac. The remote
test conversation supplied anonymized summaries; raw device logs were not copied.
Android 14, WebView 116.0.5845.195, Modu 1.2.10 (10129).

- At 20:16 and again 20:22, Chromium reported renderer exit code 11 followed by
  `Render process crash wasn't handled by all associated webviews`, then the
  application exited with SIGTRAP. This establishes an unhandled renderer loss,
  not an OOM diagnosis or a particular font/GPU root cause.
- A fresh process also showed a white reader during the first sample, then text;
  it logged 111 skipped frames. Chapter clicks were reported as not advancing
  before the later crash. Sampling does not establish precise operation latency.
- Cumulative frame percentages are not before/after performance measurements.

## Changes

- Reader and web popups dispose their failed native subtree and expose an explicit
  reload, with stale crash callbacks ignored. Reader recovery uses its latest
  recorded CFI, pauses active narration and stops translation. No automatic retry
  loop, data deletion, or preference changes.
- Dictionary falls back to its text definition. Background import/search fails
  promptly and disposes the failed WebView. Both headless/overlay paths handle it.
- Extend the existing generated Android plugin source patch (not the Pub cache):
  mark renderer loss in both WebViewClient implementations; destroy failed views
  without waiting for an about:blank load completion. Upstream anchors are checked
  and fail the build if the dependency changes.
- Ignore identical paginator attributes instead of repeating whole-chapter layout.
  Actual typography/layout changes still render. Existing E-Ink motion preferences,
  page alignment, selection, fonts and cache policies are preserved.
- Record successful/failed chapter duration and renderer-loss state in the bounded,
  current-session anonymous diagnostic stream. No book text or paths are added.

Android's contract requires each affected WebView to handle renderer loss and
remove/destroy its unusable instance:
[WebViewClient.onRenderProcessGone](https://developer.android.com/reference/android/webkit/WebViewClient#onRenderProcessGone(android.webkit.WebView,%20android.webkit.RenderProcessGoneDetail)).

## Validation

- 16 Node regression tests passed: native patch/callback coverage, repeated
  attributes, chapter loading/rollback/cancellation and scroll-mode preservation.
- Flutter: 12 recovery/translation tests and 21 recovery/search/geometry/progress/
  runtime-diagnostics tests passed (the recovery test is in both runs).
- Targeted Flutter analysis: no issues. A prior sandboxed analyzer-plugin download
  failed; the final network-permitted run completed successfully.
- Webpack build passed with existing legacy async/await target warnings.
- Production Android build via `node scripts/build_android.mjs` succeeded after
  the native cleanup patch. Generated native source inspected for all three edits.
- APK signature verified; release DEX ONNX JNI checks passed; all seven native
  libraries passed arm64 ABI and 16 KB ELF alignment verification.

APK: `/Users/sobranie/Work/下载/Modu-1.2.10-eink-test-20261016-arm64.apk`

- Package/version: `com.modu.reader`, `1.2.10`, code `10129` (not a downgrade).
- SHA-256: `378bc70b2b3a6619c59cd4a7b059ba224bb4763ed55adb31f86be262884e6964`
- Signer SHA-256: `5820b67f2d4d0eb47f965bb0045d04c13f5e51a027ad89277a3e97681da3801f`

The remote installed certificate has not been compared here. Installation must
check that certificate and use an in-place update only; never uninstall or clear
data to work around a mismatch. The package also contains the existing pending
workspace changes; it is not an isolated cherry-picked release.

## Remote follow-up and restoration

The remote test thread subsequently reported a same-signature in-place install of
the APK above at 20:35. At 20:36 the renderer still crashed, but the main process
survived and displayed the reload action. Manual reload restored readable content
and chapter/page state at 20:37; exact CFI restoration is not established (a
one-page discrepancy was reported). Startup white space and chapter latency
remain unresolved. The underlying renderer crash is not fixed.

After the user's rollback, the remote thread confirmed the original APK was
installed again and suffered another renderer crash followed by application exit.
The user then explicitly reversed that rollback. The saved source and identical
test APK have been restored locally; the APK SHA-256 was checked again. Remote
reinstallation was subsequently confirmed at 20:53 (same hash/signature, in-place
install, process 15866). The remote test recorded 99 skipped frames at 20:55;
no new crash was observed in that short sample. This is not evidence that the
underlying renderer crash has been fixed. No commit or publication was performed.

## Follow-up layout change (not in the APK above)

Layout attribute updates now commit synchronously as a batch, so changing flow,
margins and columns does not repaginate the chapter at each intermediate setting.
Unchanged attributes remain no-ops; standalone changes retain immediate rendering.
Other renderer types retain the existing attribute path. Fonts, alignment and
navigation behavior are unchanged. Unit checks cover batching, final scroll policy,
unchanged settings, failure cleanup and reader integration. Device timing is not
yet available for this additional change.

The current `nextChapter()` bridge calls `nextSection()`, which advances the EPUB
spine, not necessarily the next TOC item. Several spine sections can share a TOC
title. A title that stays the same is therefore insufficient to diagnose a failed
navigation; compare the actual text/position. This follow-up does not change that
existing behavior.

Test2 adds anonymous timing stages for resource/queue, iframe document loading,
chapter preparation, font readiness and layout. Timing callbacks bypass Flutter
setState; they do not change loading/error UI. These are current-session bounded
diagnostics, with no book text, URL or path.

Validation: 84 JS and 13 Flutter regression checks passed, targeted Flutter
analysis passed, and the production Android build and signature/JNI/ABI/16 KB
checks passed. Two initial JS tests could not find the temporary jsdom install;
after restoring that test-only dependency the complete run passed.

Second test APK (not yet device-verified):
`Modu-1.2.10-eink-test2-20261016-arm64.apk`, version `1.2.10-eink-test2`,
code `10129`, same signer as above.
SHA-256: `14cb3325d79a4f6f98ed9f5610f9e092481c4c205b184528f9b54881ca1eb6d7`.

## Stylus follow-up

The user clarified that stylus drag-selection retained thick green native handles
and the floating native selection box. The native-selection adapter treated a pen
movement beyond 8 px like finger scrolling and disabled custom handle takeover.
The new regression failed before the fix. Pen movement now cancels smart expansion
but keeps custom handles eligible for the settled range. Finger scrolling and
multi-touch still cancel takeover. The pen kind survives its compatibility touch
event. Physical OEM stylus behavior is not yet verified; this change is not in
test2 and requires a separately identified test3 package.

Test3 built successfully: `Modu-1.2.10-eink-test3-20261016-arm64.apk`,
version `1.2.10-eink-test3`, code `10129`, unchanged signing certificate.
SHA-256: `d55ca0ec7eff9d34860b7be280f73617d8a547a14a41ca0726009a7ad9bc8cd1`.
The combined JS suite passes 153 tests; the prior 13 Flutter checks and targeted
analysis cover the unchanged Dart portion. APK signature/JNI/ABI/16 KB checks
passed again. Device installation and stylus/latency results are still pending.

## Remote test3 evidence and test4 scope

Remote in-place test3 installation was confirmed at 21:14:53, main PID 16417.
First chapter ready 5587 ms included 4546 ms layout. Later loads spent
15181/13632 ms in layout versus 1042/1065 ms waiting for fonts. A later isolated
TOC click (no simultaneous UIAutomator dump) was ready in 5891 ms, including
4550 ms layout and 1 ms resource loading. Returning to the earlier chapter took
15193 ms, including 13741 ms layout and 1 ms resource loading. These samples
identify layout as the dominant phase but do not establish a paired speedup.

At 21:17:31–33, renderer 16553 again faulted at libwebviewchromium.so pc 03471c7a,
BuildId 959aa04f84c59f6ebc9659bfd6ce28592db609b5. The main process survived and
manual reload restored text. Later renderer exits around explicit reader disposal
and a UIAutomator FATAL are not counted as new natural Modu crashes. The sampled
main-process RSS peak (676 MiB) is not evidence of OOM or a leak. At 21:32, the
remote test confirmed that test3 still showed thick green native handles and the
floating gray magnifier. The private screenshot was retained remotely, not copied
into the repository. Test3 did not fix the reported device behavior.

Test4 retains the alignment algorithm and stable CFI-transparent nodes. It clones
one styled run template rather than repeatedly creating/parsing identical styles,
avoids no-op top writes, and skips computed-style reads for known generated inline
runs without skipping glyph measurements. Initial layout diagnostics now distinguish
viewport, reset, styles/images, spacing, run creation, geometry, offsets and expand.
Substages overlap chapter_layout and must not be added to it. Later refits do not
emit these additional bridge events. No content or paths are recorded.

The follow-up stylus regression reproduces another lost-takeover path: after pen
movement cancels smart expansion, native scroll-to-selection sees no smart-selection
session and cancels handle takeover again. Test4 preserves the active pending pen
range across that scroll only. Explicit navigation, a new gesture, keyboard input
and multi-touch still cancel it. The new test failed before the fix and passed
after it. This is a code-confirmed defect, not proof that every OEM-native path is
resolved; real pen selection must be retested.

Verified test4 artifact: `Modu-1.2.10-eink-test4-20261016-arm64.apk`, version
`1.2.10-eink-test4`, code `10129`, same signer. SHA-256:
`249d4598a0ea3ca69c3a4b1749ce000bc29f86bfc3ae0acc9a4d75938a34169e`.
178 JS and 13 Flutter tests passed, targeted Dart analysis passed. Production
build, signature, ONNX JNI, arm64 and all seven native ELF 16 KB checks passed.
Device installation, latency measurements and pen takeover remain pending.

## Remote test4 results / test5 follow-up

Test4 same-signature install was confirmed at 21:38:28. A natural renderer SIGSEGV
at 21:39:53–54 (PID17702, same pc/BuildId) left main PID17592 alive; manual reload
worked. Long-chapter ready/layout: 11357/9846 ms; recovery 11394/9891 ms. Recovery
layout stages were viewport2/reset2/styles1135/spacing143/runs1494/geometry2867/
offsets482/expand3756 ms. Their sum9881 differs from layout9891 by10 ms; no invented
attribution. Resource312/document122/prepare130/fonts686 ms.

Exclusive TOC samples with no UIAutomator dump: target A first ready3778/layout2584/
resource1; far target B ready3211/layout2258/resource184; returning to A ready4834/
layout2516/resource1459. Target A matches the earlier test3 isolated sample
(ready5891/layout4550), but these are not a controlled paired benchmark. The later
renderer code-1 near explicit reader disposal is not counted as a natural crash.

Real stylus feedback: green handles appear first, then reader blue circles; automatic
word expansion was explicitly confirmed as desired by the user and must remain.
This supersedes any earlier handoff wording implying that automatic expansion is
itself a bug. The user did not confirm the gray magnifier's current state. The
transition was observed by the user, not independently captured by a screenshot.

Test5 leaves the smart-expansion code unchanged. Reader-only Android WebView contexts
receive a theme overlay for blue circular native handles before native selection
starts; it does not finish ActionMode, erase the selection or alter the Activity or
normal browser themes. Chromium's HandleViewResources/PopupTouchHandleDrawable
use the container context's textSelectHandle attributes; source inspected:
https://chromium.googlesource.com/chromium/src/+/refs/heads/main/android_webview/java/src/org/chromium/android_webview/PopupTouchHandleDrawable.java
The exact OEM WebView behavior must still be verified on-device.

Horizontal alignment now measures its content extent during the read-only geometry
pass, before writing per-run vertical offsets; expand consumes that one-pass value.
There is no cross-render cache. Unsupported/rotated content, later image/font/resize
events and overlays still measure normally. This can remove a forced layout, not
just move a timer; device comparison must inspect total ready/visible completion,
not claim success merely because layout_expand falls.

Playwright CLI in an isolated Chromium session compared old post-write measurement
with the new path on 12 synthetic cases: widths360/800, fonts18/32, plain/media/
rotated content. All 1620 run rectangles, whole-content horizontal extents, outer
page sizes, text and CFI anchors matched in each case, both initially and after
height700→640 resize. No private book content was used. Temporary local server
and browser were closed; this is not an E-Ink performance measurement.

Test5 verified artifact: `Modu-1.2.10-eink-test5-20261016-arm64.apk`, version
`1.2.10-eink-test5`, code10129, same certificate. SHA-256:
`ab85853d600f52976f9bcd66392dc49aaafee7e7c00444b04ef12920b1c7065e`.
The combined JS regression suite passed; Dart remains unchanged since the 13-test
pass. Production build, signature, ONNX JNI and seven arm64 native libraries'
16 KB checks passed. The packaged resources retain ModuReaderSelection and the
blue-handle drawable. Installation, native theme behavior and device timing remain
pending. No commit/push/public release was made.
