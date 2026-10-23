# 1.3.2 touch-selection acceptance

Scope: ordinary reflowable books in paginated/swipe reading, one pair of
Android/iOS touch handles, and re-grabbing after a page-edge turn. No library
data was cleared and no physical phone was operated during this check.

## Actual simulator checks

- iPhone 18 Pro Max / iOS 27.0, using Apple's XCTest touch input and the public
  Project Gutenberg edition of *論語*. Long-press a word, extend the end handle
  to the bottom edge and hold: the reader turns once. Continuing to hold does
  not extend to the old finger location on the new page. Release, then drag
  the new visible end handle into the next paragraph: the selection extends
  while preserving its start in the previous page. Only the in-view endpoint
  is drawn; the off-screen start is not duplicated on the current page.
- The last clean iOS build reproduced failure to re-grab with a handle only
  18 logical pixels below the top safe inset. Leaving a 36-pixel gap below a
  nonzero top safe inset passed the same touch sequence. Body typography and
  pagination margins are not changed by this adjustment.
- Android API 35 ARM64 emulator, using official ADB touch input and read-only
  WebView debugging. A page-edge drag moved from page 2 to 3 and retained a
  37-character selection. Re-grabbing the visible endpoint extended it to 61
  characters without another page turn or moving the original anchor. One
  reader handle pair was present; the previous-page endpoint remained hidden.
  The final ARM64 release build (1.3.2+10157) also installed over the existing
  emulator app without clearing data; the same long-press, edge dwell and
  re-grab flow was visually rechecked with production WebView debugging off.
- macOS final debug build: double-click word selection and mouse-drag sentence
  selection in the same public book both showed the existing selection toolbar,
  with no mobile touch handles added. No private book content was sent to AI.

XCTest screenshots and observed application state were checked after the
gesture steps. XCTest's runner sometimes stalled during teardown; its step
execution alone is not counted as a passing assertion suite.

## Automated coverage

Fresh release checkout: Flutter analysis reported no issues; 3,257 Flutter
tests passed with 13 skipped, 787 JavaScript tests passed, and Python reported
205 tests with 16 skipped and no failures. The native C++ worker lifecycle
self-check also passed. The reader webpack bundle rebuilt successfully with
the existing three top-level-await/target warnings.

Selection tests cover forward/backward turns, boundary freezing, release and
re-grab, scrolling-edge speed, chapter boundaries, RTL/vertical text, mouse and
keyboard separation, native-handle adoption, viewport/safe-inset geometry,
rotation, cancellation and cleanup. Translation controls and their independent
output styles, toolbar widths, folder dragging, sync reclamation and Harmony
adapters also have regression coverage in this release.

The fresh release checkout additionally exposed a missing vendored analyzer
visitor (`nodes.g.dart`), previously hidden by the blanket generated-file
ignore rule. The required upstream source is now explicitly retained; no
runtime dependency or lint rule was removed to make the check pass.

## Limits

DOM selections remain within one chapter; original-page PDF interaction is not
replaced by the reflowable-book selection implementation. Simulators do not
establish physical-device/E-Ink acceptance. Windows/Linux native selection
and every screen size were not manually exercised in this round. Package
generation, architecture/signature verification and release/mirror delivery
are separate gates, not implied by these gesture observations.
