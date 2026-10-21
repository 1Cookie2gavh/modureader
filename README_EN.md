<p align="center">
  <img src="assets/icon/modu-app-icon.png" width="96" alt="Modu app icon">
</p>
<h1 align="center">Modu Reader</h1>
<p align="center">
  <a href="README.md">简体中文</a> · <a href="README_EN.md">English</a>
</p>
<p align="center">An open-source, cross-platform reader for ebooks, PDFs and scanned books. Crop and enhance pages, use on-device OCR and split-view comparison, translate, listen aloud and explore reading tools. Link public WeRead information and sync reading data through WebDAV or S3-compatible storage, with optional local or remote semantic indexing.</p>

<p align="center">
  <a href="https://github.com/sobranie2406/modureader/releases/latest"><img src="https://img.shields.io/github/v/release/sobranie2406/modureader?style=flat-square&amp;color=356858" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-536878?style=flat-square" alt="GPL-3.0-or-later"></a>
  <a href="#downloads"><img src="https://img.shields.io/badge/platforms-Android%20%C2%B7%20iOS%20%C2%B7%20macOS%20%C2%B7%20Windows%20%C2%B7%20Linux%20%C2%B7%20HarmonyOS-6d756c?style=flat-square" alt="Android, iOS, macOS, Windows, Linux and HarmonyOS"></a>
</p>
<p align="center">
  <a href="https://github.com/sobranie2406/modureader/releases/latest"><b>Download</b></a> ·
  <a href="https://gitee.com/sobranie2406/modureader/releases">Gitee mirror</a> ·
  <a href="#features">Features</a> ·
  <a href="docs/SETTINGS.md">Settings guide</a> ·
  <a href="docs/README.md">Documentation</a> ·
  <a href="https://t.me/Modureader">Telegram channel</a> ·
  <a href="https://t.me/ModuReaderDiscussion">Telegram group</a> ·
  <a href="https://github.com/sobranie2406/modureader/issues">Feedback</a>
</p>

## Community and feedback

Connect with the Modu Reader community on Telegram or QQ:

| Community | What you will find | Address / group number |
| --- | --- | --- |
| **Modu Reader · Telegram channel** | New releases, changelogs and project updates | [https://t.me/Modureader](https://t.me/Modureader) |
| **Modu Reader · Telegram discussion group** | Reading discussions, help using the app, bug reports and feature suggestions | [https://t.me/ModuReaderDiscussion](https://t.me/ModuReaderDiscussion) |
| **Modu Reader · QQ group** | Chinese-language discussion, help using the app and feedback | **1009765685** — search for the group number in QQ to request to join |

Please submit bugs and feature requests through [GitHub Issues](https://github.com/sobranie2406/modureader/issues/new/choose). If you cannot use GitHub, use the [feedback form](https://docs.qq.com/smartsheet/form/dxaiuhjrhCar%2Ft00i2h%2FvI8Bvs?tab=t00i2h). Describe one issue or idea per report and include the Modu version, OS and device, reproduction steps and expected behavior. Do not share keys, passwords, private books or unredacted logs.

![Original demo books on the iPhone bookshelf and in a Mac folder](docs/images/showcase/v1.3.0/bookshelf-en.png)

A green **Indexed** badge appears at the top left of indexed covers. Color-coded badges at the bottom left show the original file format, such as EPUB, PDF, TXT, MD or FB2; books identified or manually set as scans also show **Scanned**. TXT and Markdown imports retain their original-format labels after conversion to EPUB.

![Reading settings on iPhone and single-column reading on Mac](docs/images/showcase/v1.3.0/reading-en.png)

> **Local reading does not require an AI account.** AI, online translation and online speech are optional; availability and costs depend on your chosen providers. See [Releases](https://github.com/sobranie2406/modureader/releases) for version updates and usage notes.

Modu has no in-app unlock purchases or subscriptions. Fees charged by online service providers are separate from Modu.

<a id="downloads"></a>

## Downloads

| Platform | Published architectures | Installation                                                                                                                                |
| -------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Windows  | x64, ARM64              | EXE installer with shortcuts and an uninstaller; no commercial code signature; requires WebView2 Runtime                                    |
| Linux    | x64, ARM64              | DEB for Debian 13 (trixie); install with APT to resolve system dependencies                                                                 |
| Android  | arm64-v8a              | APK signed with the project's dedicated key; verify the download source before installing                                                   |
| macOS    | x64, ARM64              | DMG; drag the app to Applications; unnotarized, not an App Store release                                                                    |
| iOS      | ARM64 devices           | iOS 16+; IPA has no Apple distribution signature and cannot be installed directly; you must sign it yourself using a valid signing identity |
| HarmonyOS | ARM64 | Unsigned native HAP; requires HarmonyOS credentials/profile and manual signing before installation. Not yet device-validated; not an Android APK. |

<details>
<summary>Installation, updates and release notes</summary>

**Latest release: 1.3.0** — adds optional WeRead metadata linking and sync, current-page reflow translation with selection tools, and TXT/Markdown export of saved text. Unifies light/dark menus and settings and fixes macOS transition flicker while retaining animations. WeRead keys transfer only with explicit sensitive-settings opt-in; personal ratings/reviews stay independent. Sync remains on protocol v9.

Reader shortcut settings are restored and hardware-keyboard playback controls are improved. iOS adds optional in-place book access; HarmonyOS gains a reader wakelock bridge and corrected log-export path validation. See the [release notes](docs/RELEASE_NOTES.md) for device-validation scope, limitations and installation requirements.

Modu checks for updates at launch. Settings → About Modu → App updates uses one GitHub/Gitee source selector for both checking and downloading, defaulting to GitHub. After switching sources, check again before downloading. Failed GitHub requests fall back to Gitee while size and SHA-256 verification remain mandatory. macOS downloads open in your browser. Gitee hosts packages, documentation and update metadata; old releases are replaced by the newest release, with links to the corresponding GitHub source.

Settings → Appearance lets you choose an app language or follow the system. Bundled AI prompts follow that language; your edited prompts retain their original text.

Here, x64 means x86-64; ARM64 is also 64-bit. There is no x64 iPhone/iPad device package.
Download the installer and its SHA-256 file from [Releases](https://github.com/sobranie2406/modureader/releases), choosing your system and architecture.

Desktop apps use native installers. Download the installer for your platform, not GitHub's automatically generated source archive. Licenses are included in each package. See [Release and installation instructions](docs/RELEASING.md).

</details>

<a id="features"></a>

## Features

A library for your books, a workspace for your thoughts, and tools you can make your own.

| Module | What you can do |
| --- | --- |
| [Library](#library) | Import seven ebook formats, organize folders, pin books and browse a remote library |
| [Reading & styles](#reading) | Tune typography, switch layouts and apply visual CSS presets |
| [PDF & scanned books](#scanned-books) | Crop margins, set panel order and enhance original pages |
| [On-device OCR](#ocr) | Download lightweight models, reflow recognized text and extract passages for AI |
| [Original/reflow comparison](#reflow-compare) | Stacked in portrait, side by side in landscape, with independent controls |
| [WeRead connection](#weread) | Confirm an edition and link its metadata, ratings, reviews and popular highlights |
| [Custom CSS](#css) | Visual rules, custom code, multiple profiles and visible effects on the page |
| [Listening](#listening) | Choose a voice, edit narration prompts and listen at up to 4× speed |
| [AI reading](#ai) | Ask about chapters, customize skills and continue conversations |
| [Selection tools](#selection) | Toggle and reorder actions; create your own AI commands |
| [Full-text translation & search](#translation) | Read inline translations, switch display modes and search selected text |
| [Offline dictionaries](#dictionary) | Import your dictionaries and see definitions beside the selected word |
| [Unified lookup](#unified-query) | Dictionaries, encyclopedia, translation and AI Knowledge in one window |
| [Notes & highlights](#notes) | Capture passages, add comments and export notes with links back to the book |
| [Reading history](#statistics) | Review reading time, trends, recent books and per-book progress |
| [Vector indexing](#vector) | Build local book indexes for semantic search and retrieval-augmented answers |
| [Sync & database backup](#data) | Sync through WebDAV or S3-compatible storage and export or restore library backups |
| [Global settings backup](#backup) | Transfer preferences by file or link, with credentials controlled separately |

Feature images combine phone screenshot references with Mac promotional renderings based on the actual application, using a consistent light-theme presentation. Reading uses original demo content; WeRead shows authorized public book information, not personal notes, reviews or credentials. Headings are localized; the illustrated application language remains Chinese. Try [The Quiet Reader](docs/examples/modu-reading-demo-en.epub). See the [source-checked detailed feature guide](docs/FEATURES.md) for workflows, defaults and limits, and the [settings guide](docs/SETTINGS.md) for entry points.

<a id="scanned-books"></a>

## Original pages, easier to read

Keep the original layout of a PDF or scanned image book while making the page fit your screen. Dedicated reading controls replace text-book typography settings only for PDFs and books classified as scans.

- **Crop the margins:** automatic cropping detects content bounds on each page; adjust the safety margin or drag a crop rectangle manually.
- **Read in the right order:** split a page into panels, set their order, rotate the page and choose single-page or continuous-scroll reading.
- **See the details:** fit the page to the screen or its width, zoom in, and enhance stroke strength, contrast, darkening, paper whitening or sharpness.
- **Compare with the original:** preview changes and optionally fade scanned watermarks. Crop and enhancement settings do not rewrite the source book.
- **Prepare adjacent pages:** device hints and measured processing time determine a one/two-panel lookahead for cropping, enhancement and decoded backing images. Zoomed details are refined separately; rapid jumps may still require waiting.

![Page controls on iPhone and an original page on Mac](docs/images/showcase/v1.3.0/scanned-pdf-en.png)

EPUB, MOBI, AZW3 and FB2 image books are identified during import, not every time you open them. You can also change the classification in the bookshelf menu. Ordinary text books retain their familiar controls.

<details>
<summary>Image processing and e-ink controls</summary>

Automatic crop settings can apply throughout the book, with bounds detected separately for each page. Keep a little margin to protect footnotes and page numbers. Scanned watermark fading is image processing, not guaranteed reconstruction of text hidden beneath a watermark; always compare the result with the original.

The menu follows the app theme. E-ink-only refresh controls appear when E-INK mode is enabled; hardware refresh support depends on the device. Ordinary text ebooks retain their normal reading menus and styles.

</details>

<a id="ocr"></a>

## Turn scans into readable text

Go beyond an image of the page. Recognize text locally, then read the result **inside the reader**, with adjustable typography, selection tools, highlights, notes and AI actions.

![Text reflow and background OCR controls on iPhone, with original/reflow comparison on Mac](docs/images/showcase/v1.3.0/ocr-en.png)

1. In **Settings → Model settings → OCR model**, choose a model and download source. **PP-OCRv4 Chinese / English** is the recommended starting point. Devices without internet can use **Offline import** on the model card to select the matching complete files.
2. Open **Text → Text reflow** in the PDF/scanned-book menu. It prefers an available text layer and falls back to OCR, using the current original page or cropped area while retaining saved recognition and corrections.
3. Select text in the original or translated reflow to use the shared copying, lookup, translation, annotation, AI and selected-text speech tools. Page translation handles only the current original page, prefers corrected text, and supports translation-only or bilingual display.
4. For a specific passage, use region extraction and continuous recognition to select, recognize and edit text. Sending it to AI first opens an **editable draft**, without automatic submission.
5. Optional background OCR prepares up to five original pages, including the current page. Existing recognition or corrections are reused; prefetching continues inside reflow. Export saved text from the Text menu as TXT or Markdown, preferring corrections.

<details>
<summary>Lightweight models, offline use and limitations</summary>

| Model | Download size | Use |
| --- | --- | --- |
| PP-OCRv4 Chinese / English | About 14.9 MiB | Recommended general choice |
| PP-OCRv5 Chinese / English | About 20.5 MiB | Newer mobile model |
| PP-OCRv3 Chinese / English | About 12.5 MiB | Smaller alternative |
| PP-OCRv3 English | About 10.9 MiB | Lightweight English recognition |

Models are downloaded on demand, not bundled in the installer. Choose the upstream host or Gitee mirror, or import files offline. Only the catalogue's pinned versions are accepted; the complete file set is verified by size and SHA-256 before installation. Delete a model from its card to reclaim space without deleting books or recognized text.

OCR runs on the device after download and needs no API key. Sending extracted text to an online AI provider is a separate action. Recognition quality depends on scan clarity, language and layout; check names, numbers and complex columns against the original. OCR does not automatically index the entire book or rewrite the source PDF.

</details>

<a id="reflow-compare"></a>

## Compare the original with reflow

PDFs and scanned books can display the original page alongside its reflowed text: original above reflow in portrait, original on the left in landscape. Both panels follow the original page number and retain their own reading controls.

- Keep cropping, panels, rotation and fitting on the original side, with zoom up to **8×**. Dragging or arrow keys pan a zoomed page instead of turning it; tap-to-turn retains zoom and position.
- Select, annotate, look up, translate or listen on the reflow side. Narration stops at the end of the current original page, never automatically turns pages, and does not sync its playback state.
- Desktop keyboard actions affect the focused panel while preserving reflow text-selection and editing shortcuts.
- Toggle comparison from the original page's Text menu or OCR interface without rewriting the source book.

![Top-and-bottom comparison on iPhone and side-by-side comparison on Mac](docs/images/showcase/v1.3.0/reflow-compare-en.png)

<a id="weread"></a>

## Link WeRead book information

Enable **Settings → Appearance → Connect WeRead** and enter the API Key for the official Skills interfaces. Then link a book from its details page: search by title and author, check ISBN, translator and edition, and confirm the match yourself. You can change the link later.

- View the cover, description, publication information, WeRead rating, reader reviews and popular highlights. **These remain separate from your own rating and review.**
- Expand reviews or highlights to load them on demand. Cached results show their source and update time, with an **Open in WeRead** link.
- Replacing a local cover or description requires separate confirmation. External highlights are not assigned to local page numbers or text selections.
- Links and loaded metadata sync alongside downloaded books, not ahead of the book download. The API Key transfers only through explicitly enabled sensitive-settings sync or credential export; the query switch stays device-local.
- Book contents are not uploaded to WeRead, and lookup failures do not interrupt local reading.

![WeRead settings on iPhone and public cover, description, publication details and rating on Mac](docs/images/showcase/v1.3.0/weread-en.png)

<a id="library"></a>

## Your library, your way

Bring EPUB, PDF, MOBI, AZW3, FB2, TXT, Markdown and text UMD books into one library. Import selected books from local or remote folders. Search by title, filter by reading status, group books into folders, or pin the ones you want to keep close.

- Select multiple books to create a folder or move them into an existing one.
- Browse a separate WebDAV library, search and sort files, then download books for offline reading.
- Import an ANX Reader ZIP backup through the migration entry in Advanced settings.
- Switch between thumbnails and a cover-free list. Long press or desktop right-click enters selection mode and reveals book menus.
- On iOS, optionally add supported files/folders in place without copying originals. Originals are not automatically uploaded or included in backups; formats requiring conversion still use ordinary import.

![Demo bookshelves on iPhone and Mac](docs/images/showcase/v1.3.0/bookshelf-en.png)

<details>
<summary>Remote library and migration details</summary>

The remote-library connection is separate from synchronization: it reads and downloads files without uploading or deleting server content. Configure it in Settings → Remote library settings. Anonymous and username/password access are supported; prefer HTTPS and a read-only account. Downloads are one at a time, with a 512 MiB per-file limit and duplicate checks.

ANX backup import validates and merges supported records while retaining existing Modu data and creating a pre-import database snapshot. Read the import screen's compatibility notes before proceeding.

</details>

<a id="reading"></a>

## Make every page your own

Adjust fonts, font thickness, line spacing, paragraph spacing and margins. Use separate body and Latin fonts, choose paginated or scrolling reading, and make the page comfortable for your screen.

- Tap the page for chapter/page navigation; drag the progress slider to preview chapter titles.
- Choose themes and backgrounds, or use dark, OLED and e-ink modes.
- Manage named CSS profiles with editable presets, visual controls, regex highlights and optional custom code. Enable several profiles together or import/export them.
- Horizontal prose pages finalize spacing from the actual viewport, fonts and all four margins before display, preserving natural chapter endings. Settled scrolls prefer complete lines: bottom edge when moving down, top edge when moving up, without hiding edge text.

![iPhone reading settings and the Mac style menu](docs/images/showcase/v1.3.0/styles-en.png)

### A rhythm for vertical reading

Switch suitable books to vertical typesetting, with optional frames and column rules.

![Writing-direction settings on iPhone and vertical reading on Mac](docs/images/showcase/v1.3.0/vertical-en.png)

<details>
<summary>Typography, navigation and CSS details</summary>

Settings → CSS settings provides 32 named profiles and 13 editable presets. Detailed editing stays in Settings; the reader applies your profiles. See [CSS presets](docs/CSS_PRESETS.md).

Font thickness ranges from 0.5 to 2.0 in 0.1 steps. The optional Simulated bold control can add weight to fixed-weight fonts above 1.0; it cannot make a fixed bold face thinner. PDF and other fixed-layout pages are not re-typeset.

Scrolling page steps can be set from 80% to 100%. Long-press selection can expand to a word or paragraph, then be adjusted with the selection handles. Footnotes open within the reader. Vertical typesetting supports optional frames and column rules for suitable books.

Choose an app language or follow the system in Settings → Appearance. Bundled AI prompts follow that language; your edited prompts keep their original text.

</details>

<a id="css"></a>

## Your CSS rules, visible on the page

Start with visual presets for colors, spacing and underlines, then add custom CSS when you want finer control. The phone shows profile configuration; the Mac illustrates dialogue colors, underlines and keyword highlights.

![CSS profiles on iPhone and a Mac reading page](docs/images/showcase/v1.3.0/css-en.png)

- 32 named slots and 13 editable presets, with independent switches and combined activation.
- Visual controls for page typography and layout; regex rules for dialogue and keywords.
- Edit centrally in Settings and apply from the reader, with per-book activation choices.
- Import a plain CSS file or a Modu JSON profile; export the current or all nonempty profiles.

<details>
<summary>Presets, scope and file exchange</summary>

Presets cover novels, vertical spacing, images, centered headings, long-form text, English paragraphs, poetry, tables, dialogue colors/wavy lines, keyword/date highlights and heading underlines. Choose all text, headings or body scope; set your own keyword in the rule.

Page CSS controls layout. Regex highlights style matching text with colors, backgrounds and underlines without changing the book text or annotation positions. JSON preserves visual parameters, expressions and scope. Import only trusted CSS: remote resource URLs may make network requests. See [CSS profiles](docs/CSS_PRESETS.md).

</details>

<a id="listening"></a>

## A voice for every story

Listen with system speech, Edge TTS, Xiaomi MiMo, OpenAI-compatible services or DashScope. Start from the current position or selected text, and keep listening across chapters.

**Start with a template, then make the voice your own.** Choose natural narration, bedtime reading, fiction performance, knowledge explanation, classical recitation or news reading. Edit the description and append suggestions for articulation, pauses, tone and pace.

![Voice settings on iPhone and narration highlighting with playback controls on Mac](docs/images/showcase/v1.3.0/listening-en.png)

- MiMo offers preset voices and voice design through descriptions of timbre, tone and delivery.
- OpenAI-compatible speech settings offer an instructions switch, templates and an editable prompt.
- A compact reader toolbar provides return to narration, previous passage, play/pause, next passage and start from this page.
- Each book remembers its narration position and highlight. Reopening restores the highlight while paused; press Play to continue. The position can sync to the same book on another device.
- Long passages follow page boundaries using system word callbacks or an online audio-duration estimate, while retaining upcoming-audio caching.
- Online narration supports up to 4× playback, with separate 3× and 4× slider steps after 2×.

<details>
<summary>Voice prompts and playback details</summary>

Find these controls in Settings → Narrate. Selecting a description template fills the editor; suggestions append text for further editing. For example:

> Read in a natural storytelling style with clear articulation, moderate pauses between sentences, and steady emotion, suitable for long listening sessions.

Descriptions guide delivery; they are not spoken book text or additional official voice IDs. MiMo's rate slider adjusts local playback speed from 0.5–4.0× without regenerating audio. Prompt support depends on the service; instructions are not sent to tts-1 / tts-1-hd and can be disabled for incompatible endpoints.

Edge, MiMo, OpenAI-compatible and DashScope synthesis groups neighboring sentences within natural paragraphs, splitting long paragraphs. Highlighting and previous/next controls follow each passage; system speech retains sentence navigation. Upcoming passages are prefetched during playback.

</details>

<a id="ai"></a>

## Turn reading into a conversation

Ask about a passage, summarize a chapter, examine an argument or organize ideas into a mind map. Configure your own AI provider and choose which reading tools it may use.

- Built-in and custom reading skills can be enabled, disabled, edited and reordered together.
- Turn on “fill the input first” to add a chapter range or extra instructions before sending.
- Continue with follow-up questions in the current conversation or a restored historical conversation.
- View mind maps full screen, zoom and pan, collapse branches, and export them.

![AI skill configuration on iPhone and a demo-chapter summary in the Mac dialog](docs/images/showcase/v1.3.0/skills-en.png)

<details>
<summary>Models, skills and conversation context</summary>

Supported protocols include OpenAI-compatible, Claude and Gemini. Configure endpoints, keys and model parameters in Settings → AI settings. Service capabilities and charges depend on the provider.

Home AI works with library, notes and reading records. Reader AI works with the current book, chapter or selection. Enabled tools can retrieve chapters, search text and inspect notes; answers depend on the material actually retrieved.

Common skills include chapter/book summaries, concept explanations, argument analysis, character tracking, quote collection, reading guides and mind maps. Mind maps export as PNG, SVG, Markdown, FreeMind (.mm) or JSON. Completed reader answers return to their first paragraph.

</details>

<a id="selection"></a>

## Put your favorite tools at your fingertips

Choose what appears when you select text. Keep useful actions close and hide the ones you do not need.

- Toggle and drag-sort built-in tools, annotation controls and custom AI commands.
- Edit command names, icons and prompts; common AI templates start disabled.
- Choose selected text only or selected text with context, and opt into online search per command.
- Selection templates are managed separately. AI Knowledge, Book AI and individual skills retain separate histories and sending preferences; AI Knowledge does not search local books.

![Selection-toolbar settings on iPhone and actual text selection on Mac](docs/images/showcase/v1.3.0/selection-en.png)

AI Knowledge uses your current model's knowledge first. If further checking is needed, use **Online search** beneath the answer, before Regenerate and Copy, to retrieve Wiktionary, Wikipedia and Baidu Baike material in the same conversation. The same model summarizes the results with sources. No separate search API key is needed.

<a id="translation"></a>

## Read beyond one language

Read translated paragraphs **directly on the book page**, rather than in a separate selection popup. Choose **Original + translation** for inline bilingual reading, or **Translation only** for a continuous translated view.

![Selection-tool settings on iPhone and a translation lookup on Mac](docs/images/showcase/v1.3.0/translation-en.png)

Open the reader's translation controls, choose an engine and target language, then translate the current reading content. Translation follows the reading position; this is not a one-click export of a translated copy of the entire book. The stop action stays in the toolbar rather than covering the text.

- Google translation, AI translation and DeepL/DeepLX.
- Selection translation also offers embedded webpages, including Baidu and Youdao; these are separate from inline full-text translation.
- Selection search with Baidu, Bing, Google, Baidu Baike, Wikipedia or a custom engine in the built-in browser.

The image shows selection-tool configuration and a translation lookup for “思考”. Inline translation and selection translation have separate entry points. Online translation sends the requested text to the selected provider.

<a id="dictionary"></a>

## Understand a word without losing your place

Select a word and read its definition right beside the book. Imported MDX and StarDict dictionaries work offline, with no AI account required.

![Dictionary import on iPhone and an actual definition lookup on Mac](docs/images/showcase/v1.3.0/dictionary-en.png)

Name, enable, disable or remove dictionaries in Settings → Selection toolbar → Custom dictionaries. Query one or several dictionaries, with sources and explicit no-entry results, or opt into Chinese/English Wiktionary. Newly imported MDX dictionaries can use MDD/local resources to display original images, audio and script-generated content inline. Older text-only imports need reimporting to add these resources. Dictionary files are not bundled; the picture shows an actual lookup in an installed dictionary.

<a id="unified-query"></a>

## One window, a clearer meaning

The default-enabled **Lookup** selection tool combines dictionaries, encyclopedia, translation and AI Knowledge results. Book AI, Classical Chinese translation and Web search have separate tabs. Choose sources independently; AI supports editing before sending and follow-up questions. Existing standalone tools remain available, disabled by default. Online queries require the relevant service configuration and send the term or selected context.

![Tool configuration on iPhone and translation/encyclopedia results in Mac unified lookup](docs/images/showcase/v1.3.0/unified-query-en.png)

Desktop and Android hardware keyboards support customizable paging, menu, play/pause and previous/next paragraph keys under **Reading → Reader shortcuts**, with multiple bindings and restore defaults. Playback and pause share one key, P by default.

<a id="notes"></a>

## Keep what stays with you

Highlight a passage, underline an idea and add your own thoughts. Review notes by book and chapter, then return to the original passage when you need its context.

- Choose highlight colors and annotation styles.
- On mobile, use Quick mark to swipe over text and save a highlight.
- Export Markdown, TXT or CSV with original passages and creation or last-edit times.
- Reading-position links in exports reopen the corresponding book location in Modu when that book is available.

![Annotation-tool configuration on iPhone and the demo book's notes panel on Mac](docs/images/showcase/v1.3.0/notes-en.png)

<details>
<summary>Deleting annotations and exporting notes</summary>

Select part or all of an existing highlight or underline, choose the trash action and confirm to delete the complete overlapping annotation and its comment. The confirmation appears above the toolbar and color palette.

Exports distinguish the original passage from your comments; Markdown also highlights the note content. Quick mark works with reflowable text, not scanned PDF images, and has an explicit Exit control to restore normal gestures.

</details>

<a id="statistics"></a>

## See your reading take shape

Follow reading time, reading days, streaks and progress through individual books. Switch between periods to see how your habits change.

- Review time trends and the reading heatmap.
- Explore per-book reading records.
- Rearrange dashboard cards and keep the metrics you care about.
- Reset the default card layout from history editing mode without deleting reading records.
- Reading History includes Recently read, This week, Daily reading average and Most annotated cards. Tap a book title or cover to continue reading; deleted books retain their history and show a notice.

- The daily goal defaults to 10 minutes across books. Multiple reading rounds and per-round statistics sync with reading time through protocol v9.

![Daily reading-goal settings on iPhone and Mac](docs/images/showcase/v1.3.0/statistics-en.png)

<a id="vector"></a>

## Find ideas, not just words

Vector indexing turns book passages into searchable representations of their meaning. Combine keyword and semantic search to find relevant text, then let AI use retrieved passages as context for its answer.

1. Choose a local ONNX model or a remote embedding API in Settings → Model settings → Vector model.
2. Download or import the matching model and tokenizer offline, verify their size and SHA-256, then index a book from its menu.
3. Follow the background indexing task; use the resulting index for retrieval.

![Embedding model settings on iPhone and the Mac in-book AI dialog](docs/images/showcase/v1.3.0/vector-en.png)

<details>
<summary>Local models, downloads and privacy</summary>

| Local model | Languages | Dimensions |
| --- | --- | --- |
| all-MiniLM-L6-v2 | English | 384 |
| BGE Small EN v1.5 | English | 384 |
| BGE Small ZH v1.5 | Chinese | 512 |
| Multilingual E5 Small | Multilingual | 384 |

Models and tokenizers are downloaded on demand, not bundled in installers. Choose Hugging Face or the [Gitee model mirror](https://gitee.com/sobranie2406/modu-models/releases/tag/models-v1); downloads are checked by size and SHA-256. Verified local models can run offline without an API key.

Automatic indexing after import is off by default. Indexes stay local and are not included in WebDAV library sync. Reindex when changing the embedding model. **The chat model and embedding model are separate settings:** one generates answers; the other helps retrieve relevant passages.

Local embedding computation stays on the device. Remote embedding services receive the text to be indexed; online AI services receive the context used for their answers.

</details>

<a id="data"></a>

## Continue on another device

Use your own WebDAV server or S3-compatible object storage to sync books, notes, bookmarks, reading progress and per-book narration positions. Both connection profiles are retained separately; switching does not move cloud files automatically. With narration-aware versions on both devices, reopening restores the highlight without automatically speaking. Keep a database backup before changing devices or restoring a library.

- Automatic sync, Wi-Fi-only controls and optional timed sync during foreground reading.
- Sync promptly on startup, foreground/unlock with network restoration and book exit, after reading/narration positions are saved. Persist unfinished requests for automatic retry, while retaining Jianguoyun rate/cooldown protection and Wi-Fi-only preferences.
- ZIP database backup export/import with a visible save location.
- Backup includes local books, covers, notes, reading records, AI chat history and general settings.
- Sensitive service settings are excluded by default; backup export can optionally include them with encryption.
- Personal ratings/reviews, reading rounds and loaded WeRead metadata can sync. OCR cache and corrections follow their source book rather than downloading ahead of it.

![Sync settings on iPhone and paused narration highlighting on Mac](docs/images/showcase/v1.3.0/sync-en.png)

<details>
<summary>Restore behavior and sync security</summary>

Settings → Sync and backup → Database backup exports Modu-Backup-*.zip. Select the ZIP directly when restoring; do not extract it. Import validates then **replaces existing data rather than merging**, so back up the current library first and restart after restoring.

Windows saves to the user's Downloads folder; other platforms use the system save destination. Successful export shows the path or filename. Download any books you want included before backing up.

WebDAV sync merges records by stable identity and uses the latest reading action, not the furthest progress. Fonts, background images, local dictionaries and vector indexes are not part of library sync. Server compatibility is described in the [sync guide](docs/WEBDAV_RECORD_SYNC.md).

Sync API keys is a separate opt-in switch. Sensitive configurations are encrypted with AES-256-GCM and require the same encryption password on every device. This does not encrypt the entire library or replace a trusted server.

</details>

<a id="backup"></a>

## Take your preferences with you

Global settings backup transfers the way you use Modu: appearance, reader layout, CSS profiles, AI skills, selection tools, speech, translation and general preferences.

- Export a settings file or modu link; restore from a file or pasted link.
- Review the contents before importing.
- Keep accounts, passwords and API configurations behind an independent switch, **off by default**.
- Only changes to built-in prompt templates are backed up, alongside your custom templates.

![Global settings backup on iPhone and Mac, with credential export off](docs/images/showcase/v1.3.0/backup-en.png)

| Need | Use |
| --- | --- |
| Move preferences and custom prompts | Global settings backup |
| Back up books, notes and reading records | Database backup |
| Keep reading data aligned across devices | WebDAV / object-storage sync |

![Updated settings and appearance on Mac and iPhone](docs/images/showcase/v1.3.0/settings-en.png)

Settings files do **not** contain books, notes, chat history, font/background files, dictionaries or downloaded vector models. If you include credentials, the settings file or link contains recoverable plaintext credentials: **keep it private**. QR export is not offered; use a file for a complete settings backup.

Windows settings exports default to Downloads; other platforms use the selected save destination. The success message shows the saved location and lets you copy it.

## Getting started

1. Download the package for your system and architecture from [Releases](https://github.com/sobranie2406/modureader/releases). Follow the installation instructions.
2. Add an ebook to the library and open it. No API key is required if you do not use AI.
3. To use AI, configure a model in Settings → AI Settings and test the connection.
4. For semantic search, download a local model in Settings → Model settings → Vector model (Chinese BGE is the default), then index a downloaded book from its menu. You can also configure a remote embedding endpoint.
5. Choose translation, read-aloud and sync services as needed. See the [Settings guide](docs/SETTINGS.md) for instructions, parameter explanations and security considerations.

## Feedback

See [Releases](https://github.com/sobranie2406/modureader/releases) for version changes and downloads.

When reporting an issue in [this repository](https://github.com/sobranie2406/modureader/issues), include your version, system, architecture, reproduction steps and a sample without private information. Never submit API keys, WebDAV passwords or settings files and links containing credentials.

If Modu helps you enjoy reading, please give the repository a **Star ⭐** in the top-right corner. It helps more readers discover the project and encourages continued development. Thank you!

## Build from source

<details>
<summary>Expand build instructions</summary>

The pinned Flutter version is recorded in [.github/flutter-version](.github/flutter-version); dependencies are locked in pubspec.lock. You need Flutter's native toolchain for your platform. Building the tokenizer from source also requires Rust, including the appropriate mobile targets.

```sh
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter test --concurrency 1
# Run on the appropriate host platform:
flutter build macos --release --build-name "$(python3 scripts/release/verify_mobile.py --apple-build-name)"
# Configure Android release signing as described in docs/RELEASING.md first.
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

See [.github/workflows/build.yaml](.github/workflows/build.yaml) and scripts/release for the complete build and packaging procedure. The Dart package name remains `anx_reader` for compatibility with existing imports. The user-facing brand and application ID are Modu / `com.modu.reader`.

</details>

## Star history

Thank you to everyone supporting Modu. Click the chart to explore its growth on [Star History](https://www.star-history.com/?repos=sobranie2406%2Fmodureader\&type=date\&legend=top-left).

<a href="https://www.star-history.com/?repos=sobranie2406%2Fmodureader&amp;type=date&amp;legend=top-left">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=sobranie2406%2Fmodureader&amp;type=date&amp;theme=dark&amp;legend=top-left" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=sobranie2406%2Fmodureader&amp;type=date&amp;legend=top-left" />
    <img alt="Modu GitHub stars over time" src="https://api.star-history.com/chart?repos=sobranie2406%2Fmodureader&amp;type=date&amp;legend=top-left" width="800" />
  </picture>
</a>

## License and origins

The project is distributed under **GPL-3.0-or-later**; see [LICENSE](LICENSE).
Anx Reader's MIT copyright and license are preserved in [LICENSES/Anx-Reader-MIT.txt](LICENSES/Anx-Reader-MIT.txt).
ReadAny's copyright and license are preserved in [LICENSES/ReadAny-GPL-3.0-or-later.txt](LICENSES/ReadAny-GPL-3.0-or-later.txt).
See [UPSTREAM.md](UPSTREAM.md) and [NOTICE](NOTICE) for pinned upstream revisions, modification scope and third-party attribution. When distributing binaries, retain the licenses, identify your modifications and provide the complete corresponding source and build scripts for that version.

[Privacy](PRIVACY.md) · [Security](SECURITY.md) · [Contributing](CONTRIBUTING.md)
