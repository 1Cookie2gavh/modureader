# PDF adjacent-page preprocessing — 2026-10-13

## Change

- Native PDF continuous reading loads text/annotation frames without first rasterizing an unprocessed full page. It resolves per-page crop/panel bounds, renders the configured enhancements into a bounded full-panel backing image, and decodes that image before committing the frame.
- Preserve source text nodes, annotation coordinates, per-book settings and source files. Search anchors outside the selected panel prepare the corresponding replacement crop/original-page backing image.
- Prepare the travel direction first, including tall/zoomed pages outside the previous two-screen loading threshold. Start with one panel ahead; after three samples with a smoothed duration below 150 ms, allow two unless reported memory is <=4 GiB or CPU concurrency <=4. Missing hints use measured durations. Slow processing reduces lookahead again.
- Keep the seven-frame DOM limit and existing 2MP/2048px raster caps. Recycle base-image object URLs along with frames. The separate scroll renderer retains at most four compressed results / 8 MiB; this is not a bound on total process memory or PDF.js worker memory.
- Reuse the whole-panel processed image during scrolling. Insufficient-resolution zoomed regions are refined separately after settling, without cancelling prepared neighboring backing images.
- Single-page reading warms the next actual panel in reading order (including same-page grids), using the same adaptive budget. Foreground navigation supersedes the optional work.
- Abort signals reach automatic crop detection and scroll base rendering. Late cancelled output is discarded, and failures retain the committed page with retry available. Background readers do not start new neighbor jobs.

## Verification

130 Node tests passed, zero failed/skipped:

```sh
MODU_JSDOM_ROOT=/private/tmp/modu125-js-tests node --test --test-reporter=spec \
  test/pdf_scroll.test.mjs test/pdf_reading_renderer.test.mjs \
  test/pdf_reading_layout.test.mjs test/pdf_reading_viewport.test.mjs \
  test/document_regions.test.mjs test/document_image_processing.test.mjs \
  test/document_reading_mode.test.mjs test/document_reading_options.test.mjs \
  test/reader_annotation_alignment.test.mjs test/reader_progress.test.mjs
```

Coverage includes adaptive-budget branches, tall pages, forward/reverse traversal, full-panel reuse, cropped/enhanced requests, 1500% zoom bounds, cancellation, retry, URL disposal, text-node identity, mark geometry, and unchanged location during prefetch. Reader lifecycle tests use jsdom and mocked page renderers; image-processing tests exercise synthetic pixel fixtures. These are not real-device performance measurements.

`assets/foliate-js/node_modules/.bin/webpack --config webpack.config.js` succeeded from the reader directory and regenerated the bundled asset. Three pre-existing top-level-await/legacy-target compatibility warnings remain in `book.js`/`view.js`. `git diff --check` passed.

## Not verified

No APK/desktop installer was built or installed, and no release was published. Physical-device scroll smoothness and memory usage still require testing with the user's PDF. Fast jumps can outrun bounded preprocessing; at high zoom, finer detail may still appear after settling. No whole-book conversion or persistent processed-page cache was added.
