# Homepage illustrations

## Current bilingual set

The homepages use **18 Chinese and 16 English panels**, each **3840 × 2560**, in `showcase/v1.3.0/`. The directory name is retained for continuity; it is not a claim that every pictured state is a factory default. WebP delivery is lossless at the full output resolution. Local PNG masters are retained separately. Standalone dictionary, translation and vector-model panels have been retired; definitions, translation and AI Knowledge are shown together in unified lookup.

The approved composition uses the existing pale ivory/sage botanical background, a centered Modu wordmark and headline, a foreground phone on the left, and a slightly overlapped Mac window with its three window buttons. Mac content uses an approximately 1.41:1 window rather than an ultrawide layout. Prose is single-column; original/reflow comparison retains its two panes. AI and lookup interfaces appear as their actual popup dialogs, not invented sidebars.

Actual phone and Mac captures supply control/icon crops, navigation references, query results and AI responses. Typography, responsive card layouts and public metadata are recomposed from those references. Ordinary prose is typeset from the original demo material and expanded for the approved layout; example notes are generated from that material. Shelf layout and badge styles follow the actual app, while the displayed books use public cover/catalog data. This is a composited feature presentation, not a claim that all pixels are untouched screenshots or that every older source capture was native 4K. Raw captures are not published because regions outside approved crops may contain personal information. No Computer Use badge, pointer or pointer halo belongs in the final artwork.

Chinese panels use Chinese UI and Chinese reading material. English panels use English UI and English reading material. WeRead and vertical reading appear only on the Chinese homepage.

| Panel | Phone | Mac |
| --- | --- | --- |
| reading | Single-column prose and actual progress menu | Single-column prose and actual progress menu |
| bookshelf | Classic books, actual shelf navigation, format/index states | Same localized books, actual desktop navigation and badge design |
| styles | Actual reading-style popup | Actual reading-style popup |
| vertical | Dense vertical demo-book prose and full page border | Same chapter and full page border, with desktop text flow |
| scanned-pdf | Original demo PDF page | Same original demo PDF page |
| ocr | Reflowed demo PDF text | Same reflowed demo PDF text |
| reflow-compare | Portrait, top and bottom | Landscape, left and right |
| weread | Authorized public metadata for 《毒堇之杯》 | Same cover, introduction, publication information and recommendation score |
| css | Styled chapter text | Same chapter, text color, underline and keyword highlights |
| listening | Highlighted passage and complete playback toolbar | Same highlighted passage and playback state |
| skills | Actual AI dialog with a genuine demo-chapter summary | Actual centered AI dialog with a genuine demo-chapter summary |
| selection | Actual toolbar over selected demo prose | Same passage and actual toolbar |
| unified-query | Overview with dictionary, translation and AI Knowledge cards | Same term and excerpts of the actual returned results |
| notes | Demo quotations and generated comments in the actual notes panel | Matching sample notes using the app's quotation/comment card structure |
| sync | Sync configuration with no personal endpoint | Matching configuration; not evidence of a cross-device sync test |
| backup | Settings export/import, credentials off | Corresponding settings-backup page |
| settings | Appearance controls | Matching appearance controls |
| statistics | History with classic bookshelf titles and simulated records | Same books and simulated records in the desktop history layout |

The WebP export removes the incorrect inverse-gamma metadata written by AppKit without changing the PNG pixel data. Decoded WebP colors are compared against the PNG masters to prevent the earlier washed-out text. Export validation also checks 3840 × 2560 dimensions, lossless encoding, distinct image hashes and all README references.

## Reading and notes

The ordinary reading material comes from the original [demo books](../examples/README.md), with longer paragraphs typeset for the artwork. The notes use quotations from this same material and newly written illustrative comments; they are not the user's private notes or copied reviews. The user authorized sending original demo chapters to DeepSeek for the AI demonstrations. The pictured answers preserve the actual returned responses. No private book or note was sent for these examples.

WeRead uses only the user-authorized public cover, introduction, publication details and recommendation information. Personal ratings, reviews, reading history, service endpoints and unmasked credentials are excluded.

## Classic-book cover and catalog sources

The bookshelf uses the following Douban catalog pages for covers, titles and authors. Covers retain their original aspect ratios. Cover artwork belongs to its respective rights holders and is not relicensed by the repository's code license. No ebook files or review text were downloaded from these pages. The artwork does not imply that Douban provides ebook downloads or endorses Modu.

Format labels, index states and percentages in this shelf illustration are demonstration states showing existing UI behavior, not claims about a particular commercial edition, actual processing measurements or the user's reading progress.

| Language | Book | Author | Catalog source |
| --- | --- | --- | --- |
| 中文 | 红楼梦 | 曹雪芹、无名氏续 | [豆瓣](https://book.douban.com/subject/30137806/) |
| 中文 | 围城 | 钱锺书 | [豆瓣](https://book.douban.com/subject/1008145/) |
| 中文 | 边城 | 沈从文 | [豆瓣](https://book.douban.com/subject/1057244/) |
| 中文 | 活着 | 余华 | [豆瓣](https://book.douban.com/subject/4913064/) |
| 中文 | 平凡的世界（全三部） | 路遥 | [豆瓣](https://book.douban.com/subject/1200840/) |
| 中文 | 百年孤独 | 加西亚·马尔克斯 | [豆瓣](https://book.douban.com/subject/6082808/) |
| English | The Great Gatsby | F. Scott Fitzgerald | [Douban](https://book.douban.com/subject/1386113/) |
| English | Emma | Jane Austen | [Douban](https://book.douban.com/subject/1118772/) |
| English | Jane Eyre | Charlotte Brontë | [Douban](https://book.douban.com/subject/1611985/) |
| English | 1984 | George Orwell | [Douban](https://book.douban.com/subject/1621586/) |
| English | The Grapes of Wrath | John Steinbeck | [Douban](https://book.douban.com/subject/1859778/) |
| English | A Christmas Carol | Charles Dickens | [Douban](https://book.douban.com/subject/1574930/) |

## Historical assets

Earlier artwork remains recoverable in Git history. Images referenced by historical documentation, including `showcase/cross-platform/`, are retained and must not be presented as current UI. Only reviewed final compositions belong in the tracked homepage set; local source captures, PNG masters and contact sheets remain outside it.
