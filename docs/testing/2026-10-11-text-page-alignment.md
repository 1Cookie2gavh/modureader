# Text page alignment — updated 2026-10-13

## Scope

- Ordinary horizontal prose: measure loaded font geometry and prepare stable inline runs while the chapter is hidden, then distribute spare page height between lines. Align first/last lines to configured margins without changing font size or saved preferences. Repairing an overlapping/zero line height can change the initial page count. Chapter-final pages keep natural spacing and bottom whitespace.
- Runs are transparent to EPUB CFI indexing. Font/viewport changes reset offsets without replacing their text nodes. Annotation geometry uses actual text fragments and merges neighbouring boxes.
- No body layout mutation on a page turn. Publisher styles, custom CSS, PDF, vertical/RTL, illustrated/table/pre/ruby/math pages and explicit forced page breaks keep native layout. A single-line page cannot align both ends without scaling the glyph and is not stretched. Preparation is bounded to 50,000 characters and requires Intl.Segmenter; larger chapters are not force-fitted.
- Tap/keyboard scroll steps and idle gestures use inter-line gaps. Prefer both edges where possible; otherwise downwards prioritizes the bottom edge, upwards the top edge. Keep overlap, endpoints, active selections and finger/inertia movement. Never mask edge text or resize/reflow the viewport to fit it. Both edges cannot always fit a mixed-size layout simultaneously.

## Earlier Android device checks (before the latest small-spacing fix)

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

`MODU_JSDOM_ROOT=/tmp/modu125-js-tests node --test test/reader*.test.mjs test/pdf_reading_renderer.test.mjs`: 491 passed, zero failed. Includes cached/uncached stop equivalence, cache invalidation, CFI compatibility, selection/TTS, annotations, chapter navigation, overlap, loading lifecycle, compositor completion/cancellation, RTL and disabled-animation fallback.

## Small-spacing and viewport follow-up — 2026-10-12

- Reproduced the user's paragraph-boundary pattern in Chrome: at 20px font / 24px line height / zero paragraph spacing, font Range boxes were 28px tall. The overlap-merging algorithm collapsed 204 lines into one interval. It now retains adjacent lines and only combines same-line/contained fragments.
- Before display, measure loaded glyph boxes and apply a readable minimum line height. Scroll layout uses the actual container height after top/bottom insets and the text wrapping produced by configured side margins; fit whole line intervals within that height where a small adjustment suffices. Saved settings and font size are unchanged. Resize/font/style changes rebuild layout; page turns do not.
- Removed the fixed 8px paginated offset limit, scaling it with actual line pitch instead. Short landscape pages allow the spare line/paragraph gap to be distributed. Explicit sparse pages and complex publisher layouts retain the safety exclusions above.
- Scroll stopping now searches at least one glyph backward on page steps, or half a glyph either way on idle settling, when the glyph fits the viewport. The previous percentage-only search could be smaller than a half-line in landscape, leaving the edge inside a character even with correct line geometry.
- Browser fixture: `test/fixtures/text-layout-matrix.html`; runner: `scripts/testing/text-layout-matrix.mjs`. Synthetic prose only. Checks measure actual Range geometry, priority-edge cuts, stable idle stops, and zero body mutations during turns/settling.
- Final standard matrix: 320×568, 390×844, 430×932, 768×1024, 1024×768 and 1366×768 CSS px at DPR 1; fonts 14/20/28/40px, line-height settings 0/1.2/1.8, paragraph spacing 0/0.6, both flows, top/bottom margins 45/30 or 80/55 and side-gap settings 5%/10%. All 288 cases and 6,601 checks passed, with no browser exceptions. Full-page text-box edges were within 1 CSS px of their configured margins; tested turns/settling caused zero body mutations.
- Additional landscape/compact matrix: 844×390 and 586×522 CSS px at DPR 2.625; four font sizes (14/20/28/40), line-height settings 0/1.2/1.8, paragraph spacing 0/0.6, paginated/scrolled modes. 96 cases, 3,060 checks passed. The initially failing 12 combinations are now covered.
- Live resize on the same document (390×844 → 844×390), serif font 20→28px, and top/bottom/side-margin changes recalculated line height without replacing the document. A 28px landscape page with margins 80/55 measured first-line top 80 and final-line bottom 335 within a 390px viewport.
- No Android device is currently connected. These new results are browser-engine checks, not renewed physical-device, iOS, HarmonyOS, or macOS-app acceptance. No installation package was built.

## Production CSS / large paragraph-spacing follow-up

The user's subsequent screenshots still showed differing bottom whitespace. The original book is unavailable and no test device is connected; the following are reproduced defects, not proof of that book's exact cause.

- Slider label 6 represents `paragraphSpacing=3`, producing 1.5em margins on each paragraph. The earlier simplified fixture tested only 0/0.6em and did not cover that setting or the complete production stylesheet.
- Extended the fixture to load the real `getCSS` implementation and its font/selection helpers. A 40px / line-height 3 / paragraph spacing 3 case left its first/last text boxes at 146/673 instead of configured 50/809: the sparse-page guard did not include the leading paragraph space released by top alignment.
- A next paragraph's margin plus first line can also exceed the remaining page space. Read adjacent block margins before any alignment writes, and include that allowance plus the last CSS line box's lower half-leading rather than relying only on average line pitch. Sparse-page and complex-content exclusions remain.
- The production DIV paragraph selector stopped matching after inserting `modu-page-run` descendants, losing line/paragraph spacing. The selector now treats these stable inline runs as transparent, while still excluding structural DIVs containing paragraphs.
- Added unit regressions for leading-space reclamation, next-paragraph margins and the production DIV selector. All 494 reader/PDF JS tests pass. Rebuilt the reader bundle; the three existing webpack target warnings remain.
- Final production pagination run (`--production --paginated-only`): 144 cases / 9,760 page checks, zero failures or browser exceptions, no body mutations during turns. Covers 360×800, 390×844, 430×932, 768×1024; 20/28/40px; line-height settings 0/1.8/3; paragraph spacing 3/5; P and DIV content. Report: `output/playwright/text-layout-matrix-production-pages.json`. The preceding full production run's 144 scroll cases passed; its six remaining pagination failures are superseded by this final pagination run, not silently discarded.
- A same-document pagination-to-scroll switch retained 42px paragraph margins at 28px font / paragraph spacing 3; one subsequent turn caused zero body mutations.
- The delivered `1.2.8-preview.2+10120` APK predates these additional fixes. No new APK was requested or produced during this follow-up.

Webpack compilation succeeds with three pre-existing top-level-await / legacy-target warnings; this work does not change the target. Native iOS, HarmonyOS and macOS validation remains pending. No release is published by this task.

## Legado reference and actual viewport sizing — 2026-10-13

Inspected Legado commit `5198645f0a504b1f6d1259885317e056ff6a4a02` (GPL-3.0):

- [`TextPage.upLinesPosition`](https://github.com/LegadoTeam/legado/blob/5198645f0a504b1f6d1259885317e056ff6a4a02/app/src/main/java/io/legado/app/ui/book/read/page/entities/TextPage.kt#L98) distributes surplus bottom space over `lineCount - 1` intervals and adjusts each line's coordinates. It skips single-line/image-ending/sparse pages and treats the two columns separately.
- [`TextChapterLayout.onPageCompleted`](https://github.com/LegadoTeam/legado/blob/5198645f0a504b1f6d1259885317e056ff6a4a02/app/src/main/java/io/legado/app/ui/book/read/page/provider/TextChapterLayout.kt#L252) finalizes line positions before publishing the page to the reader.

Modu keeps its browser/CSS-column renderer, CFI-transparent runs and existing page-turn cache. This adapts the pre-display finalization principle, not Legado's native drawing engine. Modu normalizes the first text box to the configured top, then distributes the remaining height across measured line intervals. The old four-line minimum and whitespace-based fullness heuristic could skip genuine two/three-line overflow pages at large fonts or short viewports; explicit breaks, missing columns, chapter ends and unsafe media now determine the exceptions instead. Unlike Legado's sparse-height heuristic, large paragraph margins alone no longer imply a deliberately short page. Saved font/spacing preferences are not rewritten.

A separate live-resize regression exposed a real measurement-order defect: `columnize()` kept the previous root width until `expand()`, so offsets were computed at the old wrapping width and applied to newly wrapped lines. The same visual line could contain characters with different offsets. Apply both new root dimensions **before** line measurement/alignment. Do not repair this with a second post-paint pass. Portrait 390×844 → landscape 844×390 previously produced page-edge pairs 124/343 or 78/343 instead of 50/355; after the fix, all tested full pages measure 50/355.

Validation using synthetic text and production CSS:

- 497 reader/PDF JavaScript tests passed, including selection/CFI, chapter loading, notes, existing scroll behaviour, forced breaks, two/three-line pages and non-overlapping compression.
- `--legado`: 180 combinations at 320×568, 844×390, 390×844, 768×1024 and 1366×768 CSS px; fonts 20/40/56px; line-height settings 0/1.8/3; paragraph spacing 0/3; P/DIV paragraphs and a heading. 3,922 full-page checks passed at DPR 1, maximum measured edge error 0 CSS px. 528 single-line pages were counted separately and excluded from the two-edge assertion, not treated as aligned.
- Repeated all 180 combinations at DPR 2.625 (`--legado --compact`): the same 3,922 checks passed, zero browser errors. A 1366×768 two-column spread also aligns each column independently after resizing the existing document.
- Final `--quick` regression: 96 paginated/scrolled combinations, 2,953 checks, zero failures or browser errors; tested scroll priority edges remain uncut and turns cause no body mutations.
- Durable browser checks also retain the same document/text node through portrait → landscape → portrait, preserve forced short pages and chapter-final whitespace, and assert zero body mutations on subsequent turns. See `scripts/testing/text-layout-matrix.mjs` and `output/playwright/legado-alignment-*.png`.
- The reader bundle was rebuilt successfully. The three existing webpack target warnings remain; no dependencies or build targets were changed.

These are browser-engine checks, not renewed Android/HarmonyOS/iOS/macOS-app acceptance. No APK, macOS package or release was requested or produced in this follow-up.
