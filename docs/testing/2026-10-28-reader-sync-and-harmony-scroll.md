# Reader sync completion and Harmony scroll verification — 2026-10-28

## Open reader after device sync

The pending 1.3.3 changes let an idle open reader adopt the downloaded reading
position and paused narration cursor. A paused old narration session no longer
protects yesterday's position. Active speech remains protected, and returning
to the foreground retries an unfinished WebView restore. Failed position
restores retain write suppression rather than overwriting the downloaded cursor.

The earlier task stopped after source edits: the deployed JS bundle still
considered `goTo()` returning `false` successful. Rebuilt
`assets/foliate-js/dist/bundle.js` and directly evaluated its restore function:
false stays false, success returns true, and suppression releases in both cases.

## Harmony scrolling

The existing Harmony-only 100 ms relocation limit was verified on API 26,
ArkWeb 7.0.0.105 (Chrome 144), using 1500 synthetic paragraphs and native smooth
scrolling in an isolated ArkTS WebView test package. The previous HEAD paginator
and current paginator used identical surrounding reader modules.

For the first equal-distance pair (final offset 11989.714 px):

| Measure | Before | After |
| --- | ---: | ---: |
| Range geometry calls | 6696 | 1445 |
| Element geometry calls | 326757 | 70451 |
| Geometry API time | 1203 ms | 530 ms |
| Relocation callbacks | 158 | 40 |
| rAF median / P95 | 16 / 47.9 ms | 16 / 47.9 ms |
| rAF intervals over 32 ms | 20 | 13 |

Geometry calls fell 78.4%; their measured time fell 55.9%. P95 did not improve.
The second pair had different final offsets and is not used for equal-distance
claims. This is an actual ArkWeb hotspot test, not full Flutter/native rendering
acceptance or proof that physical devices are completely free of jank.

## Checks

- Suspended-reader sync diagnostics: 26 passed.
- Reader sync, Harmony scroll, continuous/chapter scroll and auto-align: 42 passed.
- TTS page-source isolation: 12 passed.
- Built reader bootstrap: 9 passed.
- `npm run build` and `git diff --check` passed.
- Targeted Dart analysis: no errors; one existing scoped-provider dependency
  warning in `reading_page.dart`, outside the sync changes.

The emulator's existing Modu 1.3.1 installation and books were preserved.
The independent probe app and temporary network forwarding were removed.
No complete updated HAP, release, or physical-device acceptance was produced.
