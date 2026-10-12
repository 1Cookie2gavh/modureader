# Text page alignment — updated 2026-10-12

## Scope

- Ordinary horizontal prose: prepare stable inline runs while the chapter is hidden, then distribute spare page height between lines. Align first/last lines to configured margins without changing font size or page count. Chapter-final pages keep natural spacing and bottom whitespace.
- Runs are transparent to EPUB CFI indexing. Font/viewport changes reset offsets without replacing their text nodes. Annotation geometry uses actual text fragments and merges neighbouring boxes.
- No body layout mutation on a page turn. Publisher styles, custom CSS, PDF, vertical/RTL, illustrated/table/pre/ruby/math pages and large intentional gaps keep native layout. Preparation is bounded to 50,000 characters and requires Intl.Segmenter; larger chapters are not force-fitted.
- Tap/keyboard scroll steps and idle gestures use inter-line gaps. Prefer both edges where possible; otherwise downwards prioritizes the bottom edge, upwards the top edge. Keep overlap, endpoints, active selections and finger/inertia movement. Never mask edge text or resize/reflow the viewport to fit it. Both edges cannot always fit a mixed-size layout simultaneously.

## Android device checks

Honor LGE-AN10, Android 15, WebView 153, portrait 1148 × 2492 physical pixels (DPR 3.0625). Used the user's existing 《南宋行暮》, 二版自序, without exporting its text or calling AI/TTS services.

The initial page-alignment matrix used top/bottom margins 90/50 CSS px and a viewport height of 813.714 CSS px:

| Font scale | Chapter pages | First line top, non-final pages | Last line bottom, non-final pages | Final-page bottom |
| --- | --- | --- | --- | --- |
| 0.75 | 13 | 90.000–90.005 | 763.709–763.714 | 688.26 |
| 0.90 | 19 | 90.000–90.005 | 763.709–763.714 | 397.60 |
| 1.20 | 33 | 90.000–90.005 | 763.709–763.714 | 154.40 |
| 1.50 | 51 | 90.000–90.005 | 763.709–763.714 | 299.94 |

- 69 old/new text-anchor round trips through the actual application: zero failures.
- 12 next/previous page turns: zero body attribute/text/child-list mutations.
- A live selection retained its text and text-node identities across a font change. A temporary, unsaved test highlight produced one merged rectangle and was removed.
- 72 scroll checks across four font scales, 80%/100% steps and both directions: zero priority-edge cuts or unstable final positions.
- Six native Android touch swipes plus two native page taps: no cut edge in this fixture, stable final positions. These measurements do not imply both edges can fit every mixed-size layout.

## Performance follow-up

The user also reported stutter within a chapter. Initial programmatic turn checks missed native gesture long frames; passing layout checks does not prove smooth rendering.

- The uncached scroll path scanned all loaded chapter text on each step. Device sampling measured approximately 181–198 ms synchronous startup in one eight-step run.
- Scroll geometry is now prepared during layout and cached as merged, sorted document-local line intervals. Turning/settling searches only near viewport edges. View layout/resize/font changes and body text/style mutations invalidate the cache; chapter movement changes only the external offset.
- Visible-range discovery now seeks only the first and last visible nodes rather than traversing every visible glyph. Tests compare exact range boundaries against the previous exhaustive traversal.
- Horizontal animated turns use a compositor transform on the already-laid-out chapter, committing the scroll offset once at completion. Cancellation leaves the position unchanged. Disabled animation remains immediate; unsupported Web Animations, vertical and continuous modes retain their existing paths.
- Native gesture timings are checked separately. Reduced geometry-call counts alone are not evidence that all occasional long frames are eliminated.

## Automated checks and limits

`MODU_JSDOM_ROOT=/tmp/modu125-js-tests node --test test/reader*.test.mjs test/pdf_reading_renderer.test.mjs`: 482 passed, zero failed. Includes cached/uncached stop equivalence, cache invalidation, CFI compatibility, selection/TTS, annotations, chapter navigation, overlap, loading lifecycle, compositor completion/cancellation, RTL and disabled-animation fallback.

Webpack compilation succeeds with three pre-existing top-level-await / legacy-target warnings; this work does not change the target. Native iOS, HarmonyOS and macOS validation remains pending. No release is published by this task.
