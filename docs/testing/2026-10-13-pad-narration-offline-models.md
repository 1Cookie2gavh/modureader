# Pad narration and offline model import — 2026-10-13

## Scope

- Per-book narration CFI/highlight and playing/paused/stopped metadata; reopening restores a resumable session paused, never automatic audio. Metadata travels with the reading-position sync record, not device-local book IDs.
- Native keyboard handling accepts a visible **zero-height** IME (observed on Xiaomi hardware keyboard). Reading and narration-panel transport bindings keep editor/focus guards and held-key suppression.
- System TTS follows word offsets; online TTS estimates a text offset from actual audio position/duration. Progress does not advance the speech/prefetch iterator or reflow pages. Online timing is approximate, not word alignment; no known duration means ordinary passage-level following.
- Settings cards import complete pinned embedding/OCR files offline. Import validates every staged file before replacement; failed installation rolls back originals. Active model use/download blocks replacement. Model selection, books and indexes are not changed.
- Import accepts existing catalogue versions only, with app-owned size/SHA-256 metadata. No archives, arbitrary ONNX variants, external manifests or download fragments. Matching uses content, allowing upstream/mirror filenames.

## Automated checks

- `flutter analyze --no-pub`: no issues.
- Combined relevant Flutter regression suite: **642 passed, 5 skipped**. Includes sync/database migration, simulated two-device synchronization with different local book IDs, stale-state rejection, TTS, keyboard focus, offline import integrity/concurrency, and OCR/vector settings layouts/dialog cancellation.
- `MODU_JSDOM_ROOT=/tmp/modu125-js-tests node --test test/reader_tts.test.mjs test/reader_desktop_input.test.mjs`: **76 passed**.
- Native `ReaderPageKeysTest`: custom/legacy mappings, modifiers, repeats, key-up, lifecycle and reconnect checks passed.
- Release APK: signing verified, package `com.modu.reader`, `1.2.8-preview.5` / `10123`, arm64, min SDK 26 / target 35. ONNX JNI retention and all seven native libraries' 16 KB ELF alignment passed.

## Physical Pad — partial acceptance

- Xiaomi 25053RP5CC, 3200 × 2136 landscape, external keyboard connected.
- Before fix: keycode 62 did not toggle while touch playback worked. Android reported IME visible with zero height.
- Test build 10123 installed with `adb install -r`; no uninstall or data clearing. Four bookshelf entries remained after upgrade.
- In the narration panel, injected space events repeatedly toggled media-session state: PLAYING → PAUSED → PLAYING → PAUSED; screenshot confirmed paused icon and highlight.
- After unlocking, imported PP-OCRv4 `det.onnx` + `rec.onnx` through Xiaomi's system file picker. Modu displayed “导入并校验完成，可离线使用”; the current OCR selection remained PP-OCRv4.
- Imported BGE Small ZH v1.5 `model_quantized.onnx` + `tokenizer.json` through the same picker. Import/validation succeeded without changing the selected model. The subsequent local inference test reported success, **512 dimensions**.
- These were local-file replacement imports of already-installed catalogue models. Wi-Fi stayed enabled; no airplane-mode or fresh-install acceptance test was performed.
- **Still pending:** user-operated physical-key verification, book reopen/cold-start highlight restoration, long-passage page-boundary following, and OCR inference after import. The earlier sleep interruption was resolved. On continuation the user explicitly limited acceptance to successful model import/validation, so extended device testing stopped. Do not count pending scenarios as passed.
- Two-device cloud acceptance subsequently passed on build 10123: manually synced the paused position in《南宋行暮》from Xiaomi Pad, then synced/opened the same book on Honor LGE-AN10. The phone restored the same highlighted range (different screen wrapping), at 30.26%, with media-session state PAUSED and no automatic audio. This verifies manual cloud transport and receiver reopen, not automatic book-exit sync or reverse-direction/cold-start behavior. Both clients must support the new metadata to restore narration.
- Desktop layout tests passed; native macOS/Windows/Linux file-picker workflows have not been exercised.

## Follow-up: prompt automatic sync (source changes after build 10123)

- Startup, foreground/unlock and usable-network events request immediate automatic sync, regardless of bookshelf/reader or E-Ink mode. Book exit waits for reading/narration writes. Automatic-sync and Wi-Fi-only switches still apply.
- A device-local requested/completed revision pair retains pending work through cancellation/restart. A completed older upload cannot acknowledge a newer request. Failed foreground work retries after one minute through the same scheduling gate; background cancels timers but not pending intent.
- Jianguoyun retains the ten-minute interval, rolling request budget and server cooldown. Offline preflight does not advance the last-started interval. No cloud protocol or merge-conflict policy changed.
- Automated checks: sync directory plus reading-sync/settings regression tests **397 passed, 4 skipped**; four additional real-loopback WebDAV/provider tests passed (save-before-probe, locked exit/resume, auto-sync off, Wi-Fi-only/background cancellation). `flutter analyze --no-pub`: no issues.
- No new APK, installation, release or E-Ink hardware acceptance test was performed for this follow-up. Do not treat build 10123 as containing these automatic-sync changes.

## Test files and delivery

- APK and SHA-256 sidecar: `Work/下载/Modu-1.2.8-Preview-build10123/`.
- Pad staging files: `Download/Modu-offline-test/embedding/` (BGE Small ZH v1.5, ONNX + tokenizer) and `Download/Modu-offline-test/ocr/` (PP-OCRv4 det + rec), copied from verified existing desktop files. Both sets were successfully imported through the settings UI.
- No official release, push, tag, homepage image work or offline model download performed.
