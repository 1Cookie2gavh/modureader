# HarmonyOS API 26 import and bookshelf verification

## Scope and fix

- Follow-up to issue #33, reported by `xuezeyang123-hub`; the report and comments were re-read on 2026-10-16.
- The pinned OHOS WebView plugin (`528fa913763148719cde7dae2dc22dc33f15da36`) fetches loopback pages natively, then calls `loadDataWithBaseURL` with a directory-only base URL.
- ArkWeb uses that base URL for `window.location`. Dropping `?url=...&importing=...&style=...` makes the reader request `/foliate-js/null`, yielding HTTP 500 and a metadata timeout. The API 24 probe established that the original book endpoint itself returns HTTP 200 and matching bytes.
- Preserve the full URL as the base for loopback GET requests only. POST, HEAD, non-loopback handling, resource capabilities and EPUB script sandboxing remain unchanged. No broader storage or network permissions were added.
- The repair lives in `scripts/harmony/webview_615_patch.py`, not just a generated build directory. The runtime regression executes the actual transformed ETS method with mocked HTTP, checking book/import/style parameters and relative assets.

## Environment

- DevEco Studio 26.0.0.851; official `HarmonyOS 7.0.0(26.0.0)` phone image.
- Running system independently queried through HDC: API `26`, `emulator 7.0.0.107(SP8DEVC00E999R4P11)`.
- `Modu_API26`, arm64, 1280×2832, 560 dpi, 4 GiB RAM.
- Isolated local diagnostic HAP, version 1.2.10/build 10129, probe disabled; includes the loopback fix and diagnostic logging. This is not a published package or a build of unrelated pending workspace changes.
- API 24 instance/data preserved; no real user library was imported or cleared.

## Observed API 26 results (2026-10-16, Asia/Shanghai)

1. First launch: empty bookshelf hint and controls render normally.
2. System file picker → Download → `Modu-Import-Test.epub` → both import confirmations: successful metadata callback at 19:59:13.493, approximately 1.5 seconds after WebView creation. Book card appears.
3. Open imported EPUB: title and Chinese/English body render; return to bookshelf succeeds.
4. Switch grid to list: book row renders. Screenshots visually inspected, not just inferred from accessibility nodes.
5. Without restarting, import a second, different fixture (`Modu-Harmony-Test.epub`): metadata callback at 20:04:19.579, approximately 1 second after WebView creation. Both entries appear.
6. Force-stop/restart the test app without clearing data: both entries remain visible in list mode.
7. Pinned-source patch/runtime regression suite: 13 tests passed.

Evidence remains in the merged local `harmony-diagnosis-20261015/evidence` directory: grid screenshot `Screenshot_2026-10-16T200034.png`, reader screenshot `Screenshot_2026-10-16T200110.png`, and restart screenshot `Screenshot_2026-10-16T200554.png`. The runtime log captured after restart contains only the new session, not earlier import callbacks.

## Remaining limits

- The original user's grey/blank bookshelf was not reproduced on API 26. Passing these checks is not evidence of a separate bookshelf rendering fix; do not close #33 on that basis.
- API 24 previously had one manual/repeated import timeout even after the URL repair; API 26 passed both manual imports. No speculative lifecycle change was made to shared headless WebView code.
- Fixtures are small EPUBs without embedded cover images; large books, image covers, PDFs, other formats and the reporting physical device remain unverified.
- Startup still logs an unsupported `share_handler/sharedMediaStream` channel; picker import works despite it. EPUB sandbox script-block messages were also observed while body rendering succeeded; sandbox protection remains enabled.
- No commit, push, issue comment/closure or release was performed.
