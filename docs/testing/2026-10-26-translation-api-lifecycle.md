# Translation lifecycle and official API services

## Failure

The running macOS app logged `TypeError: null is not an object (evaluating 'new doc.defaultView.CustomEvent')` when starting translation. The Flutter bridge converted the failed JavaScript result into `Translation is not available for this book`. This happened before provider requests and was not a Baidu or Azure credential rejection.

The translator retained paragraph nodes from previously loaded chapter documents. A removed chapter can still have `isConnected` nodes while its `defaultView` is null. Translation style/mode changes dispatched a layout event to all retained documents.

## Changes

- Prune expired chapter nodes and queued work, disconnect their observers, and guard layout notifications/font loading against missing windows. Late results cannot modify pruned documents.
- Expose Baidu General Text Translation and Microsoft Translator in language translation. Reuse the authenticated API transport, per-paragraph pacing, cancellation and credentials used by classical translation. Translate language codes explicitly; automatic Microsoft source detection omits `from`.
- Keep classical and language translation display preferences independent. Service credentials are shared between their settings pages.
- Sync service selection, AI provider selection and credentials through the existing opt-in encrypted settings channel. Keep source/target languages, classical direction and both output styles local; ignore these keys in older snapshots without failing the rest of the import.

## Automated validation

- Reader lifecycle regression: detached documents without a window do not break start/style/stop; stale text is never sent; visible paragraphs still translate in order. 11 tests passed.
- Flutter translation transport, settings UI, popup and encrypted synchronization tests: 48 passed.
- Focused Flutter analysis passed.
- Reader compatibility bundle rebuilt.

## macOS device verification

- Built and installed the updated 1.3.3+10163 app into `/Applications/Modu.app`, preserving user data.
- Used the existing book《白居易的节日：唐诗里的岁时烟火记》and configured live services. AI, Baidu and Microsoft classical translation returned results beneath the source paragraphs; stopping translation worked.
- Both Baidu and Microsoft ordinary language translation returned Japanese text beneath Chinese source paragraphs. Neither reproduced the prior book-unavailable error. Stopped requests and restored the ordinary engine to Google after verification.
- The Baidu configuration card visibly showed 966 successful characters against its editable reference allowance of 1,000,000 after the classical translation check.
- This verifies macOS only; no new phone installation or real cross-device cloud verification was performed.

## Translation usage

- Baidu and Microsoft settings show a reference allowance and progress bar, with editable allowance and official console links. These are explicitly Modu estimates, using UTC calendar months, not official remaining balances or billing cutoffs.
- Count Unicode code points for each successful remote chunk; cached text and rejected requests do not add usage. Requests billed remotely after cancellation/timeout can be missing. AI token usage is not mixed into character allowances.
- Aggregate identical configurations across updated devices through the existing encrypted settings-sync switch. Baidu uses APP ID identity; Microsoft uses a key fingerprint (Key 1 and Key 2 are distinct because the translation API does not expose their common resource identity).
- Each installation publishes its own encrypted counter record. Merge each writer's monotonically increasing counters using maximum, never adding the same snapshot twice. Device identity/counters cannot be cloned through preference backup import.
- 37 Flutter tests passed, including offline two-device increments, repeat restore, month rollover, separate accounts, failed requests and over-quota UI. Focused static analysis passed. A real multi-device cloud round trip has not been performed.
