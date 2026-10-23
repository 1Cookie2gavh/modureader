# HarmonyOS pagination, import and file sharing

## Scope

Changes apply only to HarmonyOS. Android, iOS and desktop keep their existing
file-sharing path and WebView dependencies. No library data or original book
files are removed or rewritten.

## Findings and changes

- The pinned native WebView HTTP fallback uses the SDK's default 5 MiB buffered
  response limit. A supplied 16,662,365-byte EPUB failed to load, while a smaller
  private derivative retaining its prose imported successfully. Loopback requests
  now explicitly allow 100 MiB; remote requests retain the default. This remains
  a buffered implementation, not support for arbitrarily large books.
- The shared file helper previously invoked `share_plus`, whose resolved version
  has no HarmonyOS implementation. HarmonyOS now uses `modu/file_export` to open
  the native system share sheet with a private snapshot's file URI. Snapshot paths
  are validated; errors are sanitized. Opening the sheet is not delivery proof.
- Successful share snapshots are kept for the recipient to read; snapshots older
  than one day are cleaned on a subsequent share. Failed preparation removes only
  its own snapshot. The original book is preserved.
- Reproduced alternating page-turn rollback on the new emulator with trusted
  system touch events: page 5 advanced to 6, then
  `restoreSyncedReadingPosition` navigated back to 5. The same transaction returned
  the previous position revision after UPDATE; a read after COMMIT saw the new
  revision. This falsely triggered the existing stale-session conflict guard.
- The pinned OHOS sqflite adapter now uses an explicit native Transaction for
  both queries and writes, including DDL, batches, immediate/exclusive begin,
  commit and rollback. Closing a database rolls back an active transaction.
  The reader's conflict protection, DAO and non-OHOS database adapters are unchanged.
  Worker imports use Flutter utility modules directly, avoiding ArkUI evaluation
  in the worker. See the official [transaction API](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkdata/arkts-apis-data-relationalStore-RdbStore.md#createtransaction14).

## Verification

- `node --test test/harmony_file_export.test.mjs`: 12 tests passed, executing the
  native handler with mocked platform APIs, including validation, failure/retry
  and overlapping calls.
- `python3 test/harmony_webview_patch_test.py`, with the exact pinned upstream
  supplied through `HARMONY_WEBVIEW_UPSTREAM`: 13 tests passed. This verifies the
  patch anchors and executes the patched HTTP fallback against a simulated
  16,662,365-byte response, preserving the remote limit and request cleanup.
- `flutter test --no-pub test/utils/harmony_file_export_test.dart`: 7 tests passed,
  covering retained share snapshots, sanitized names, failure cleanup and source
  preservation, alongside existing save/export tests.

- `HARMONY_SQFLITE_UPSTREAM=<pinned checkout> python3 test/harmony_sqflite_patch_test.py`:
  7 tests passed, including real pinned-source anchors, routing and duplicate-patch rejection.
- `node --test test/harmony_sqflite_transaction.test.mjs`: 4 tests passed,
  executing the native transaction helper with mocked stores: read-after-write,
  rollback, isolation, nested-begin rejection and error propagation.

## Native emulator acceptance (2026-10-22)

The original `Modu_API26` emulator and its data were preserved. With explicit
user approval, created `Modu_API26_Retest24G`: HarmonyOS 7.0.0(26.0.0), 24 GB
storage, 4 GB RAM, 1320×2232. Its geometry differs from the original emulator
and the supplied recordings. No personal account configuration was imported.

- Native Release HAP compiled and installed successfully (test builds 10153/10154,
  final non-diagnostic build 10155). Final HAP SHA-256:
  `d7ff6079c23b06a08f0672b6844f94aa088004adbb0628abfb957e0b3d5738bc`.
- Imported the original 16,662,365-byte EPUB, including cover and illustrations.
  Automatic classification labelled it scanned; the test explicitly switched
  it to ordinary-book reading. This classification is a separate observation,
  not established as OHOS-specific and not changed here.
- Native file share opened the real HarmonyOS ShareKit sheet. Saved through the
  system's “Save as” action; received-file SHA-256 matched the original:
  `9dec9567b614ff9c2ec2aa40fb9c781ed353d4be0a7710defb619483952e82e6`.
  No file was sent to an external recipient. Cancel/retry has unit coverage,
  but was not separately accepted through the emulator UI.
- After the transaction fix, 8 consecutive forward and 6 backward system swipes
  each moved exactly one page. Forward visible text ranges were contiguous after
  excluding whitespace. Chapter-opening pages 1→5 were also continuous.
- Navigated to the end of the first text section, then physically swiped through
  the illustration section into the next text section. Settled screenshots
  displayed the correct first page; no rollback was observed.
- Book search returned matches and tapping a result navigated to the matching
  chapter. A newly added bookmark survived app replacement/restart and appeared
  in the bookmark list alongside the previous bookmark.
- Final build 10155 opened the settings and appearance pages. Wide selected the
  side navigation and split settings layout; Narrow restored bottom navigation.
  The forced wide layout is cramped on this phone-width emulator, but its layout
  control remained reachable by scrolling. These are UI smoke checks, not a
  substitute for wide-tablet layout acceptance. Auto was restored and its selected
  state verified before handoff. The local fixture server was stopped and all
  test port forwards removed.
- A diagnostic-only probe used its own new database, not the library database:
  create/migration with read-after-insert, trigger read-after-update, rollback,
  batch update/query, schema upgrade and close/reopen persistence all passed on
  the emulator. Temporary logging and WebView debugging are excluded from the
  final test build.

## Limits

This fixes a reproduced page-return mechanism; it is not proof that every
reported missing-page or transient rendering artifact in the videos is solved.
The supplied EPUB differs from the books in the recordings. Cross-chapter
rendering can lag the logical location, so acceptance used settled screen images
as well as page ranges. Not a physical HarmonyOS device test; cloud sync, remote
libraries, online AI/translation/TTS, offline model inference and all document
formats have not been accepted end-to-end here. No release or push was performed.

Private screenshots, page traces and local build logs remain outside the repo
under `/private/tmp/modu-harmony-retest-GCelVz`; no private book content is
included in this report or published.
