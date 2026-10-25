# Shelf-entry initialization with an invalid saved text position

The supplied Windows 10 / Modu 1.3.2+10157 log reports repeated `IndexSizeError`
failures in `CFI.toRange → anchor → Paginator.#display → View.init → Reader.open`:
offset 1099 exceeds a node length of 211, at section index 8. The WebView2
version is 134.0.3124.72. The source EPUB and saved CFI are not included, so the
reason the persisted location became invalid is not established.

The outer `open()` sends `onLoadEnd`, TOC and `renderAnnotations` only after
`Reader.open()` resolves. A stale saved CFI therefore prevents all three. A
valid note-entry CFI bypasses the invalid saved position, matching the report.

The initial text anchor now catches invalid range/node resolution errors within
the anchor callback, returning the same chapter's start. The paginator can
finish normally and startup reaches its existing ready/annotation callbacks.
The parsed TOC is also sent before initial navigation and refreshed afterward.
Resource/font failures are not swallowed. Normal navigation and annotation CFI
resolution remain strict; no note/bookmark records or source book files are
rewritten by this recovery. An invalid exact location cannot be reconstructed
from this log; recovery is explicitly to the chapter start.

Regression command:

```sh
MODU_JSDOM_ROOT=/private/tmp/modu-reader-regression node --test \
  test/reader_initial_position.test.mjs \
  test/reader_navigation_history.test.mjs \
  test/reader_loading_navigation.test.mjs \
  test/reader_loading_lifecycle.test.mjs \
  test/reader_text_page_layout.test.mjs
```

Coverage uses real DOM Range/CFI resolution with a 1099 offset and a 211-character
node; valid note-entry offsets; startup ready/TOC/annotation callbacks; missing
text nodes; preserved strict annotation resolution; non-text/document/font
failures; existing navigation, loading lifecycle and layout/CFI invariants.
This is a local automated regression, not a reproduction with the user's EPUB
or Windows device. No installer was produced or installed for this change.

Result: 69 tests passed, zero failed. The production `dist/bundle.js` was rebuilt
with the existing Webpack/Babel configuration and existing local dependencies;
no new project dependency was added. `git diff --check` passed.
