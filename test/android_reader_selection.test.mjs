import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
test('Android reader keeps ActionMode handles without changing normal browser menus', () => {
  assert.match(read('android/build.gradle'), /apply from: 'modu_reader_selection.gradle'/);
  const patch = read('android/modu_reader_selection.gradle');
  assert.match(patch, /!customSettings.disableContextMenu && contextMenu != null/);
  assert.match(patch, /Boolean.TRUE.equals/);
  assert.match(patch, /hideDefaultSystemContextMenuItems/);
  assert.match(patch, /items instanceof List && \(\(List<\?>\) items\).isEmpty\(\)/);
  assert.match(patch, /sendOnCreateContextMenuEvent\(\);\s+return actionMode;/);
  assert.match(patch, /def anchor = 'Menu actionMenu = actionMode.getMenu\(\);'/);
  assert.match(patch, /actionMode.getMenu\(\).clear\(\);/);
  assert.match(patch, /android.sourceSets.main.java.setSrcDirs\(\[generated\]\)/);
  assert.match(patch, /dependsOn\(patchTask\)/);
  assert.match(patch, /throw new GradleException/);
});

test('renderer loss is marked in both Android clients and destroys without navigating', () => {
  const patch = read('android/modu_reader_selection.gradle');
  assert.match(patch, /InAppWebViewClient\.java/);
  assert.match(patch, /InAppWebViewClientCompat\.java/);
  assert.match(patch, /\(\(InAppWebView\) view\)\.moduRendererGone = true/);
  assert.match(patch, /if \(moduRendererGone\) \{[\s\S]*?removeView\(this\);\s+destroy\(\);\s+\} else \{\s+loadUrl\("about:blank"\)/);
  assert.match(patch, /WebView disposal changed/);
  for (const [file, count] of [
    ['lib/page/book_player/epub_player.dart', 1],
    ['lib/utils/webView/anx_headless_webview.dart', 2],
    ['lib/widgets/dictionary/dictionary_original.dart', 1],
    ['lib/widgets/reading_page/selection_search_browser.dart', 1],
    ['lib/service/translate/web_view.dart', 1],
  ]) {
    assert.equal(read(file).match(/onRenderProcessGone:/g)?.length, count,
      `${file}: every associated WebView must handle renderer loss`);
  }
});

test('Android reader clears menus inside creation and refresh callbacks before showing UI', () => {
  const patch = read('android/modu_reader_selection.gradle');
  assert.match(patch, /super.startActionMode\(moduReaderActionCallback\(callback\)\)/);
  assert.match(patch, /super.startActionMode\(moduReaderActionCallback\(callback\), type\)/);
  const callback = patch.slice(patch.indexOf('private ActionMode.Callback moduReaderActionCallback'),
    patch.indexOf('private static Context moduReaderContext'));
  assert.match(callback, /disableContextMenu \|\| contextMenu == null\) return callback/);
  assert.match(callback, /EDIT_TEXT_TYPE\) return callback/);
  assert.match(callback, /hideDefaultSystemContextMenuItems/);
  assert.match(callback, /boolean created = callback.onCreateActionMode\(mode, menu\);[\s\S]*?menu.clear\(\);\s+return created;/);
  assert.match(callback, /boolean changed = callback.onPrepareActionMode\(mode, menu\);\s+boolean hadItems = menu.size\(\) > 0;\s+menu.clear\(\);\s+return changed \|\| hadItems;/);
  assert.match(callback, /callback.onActionItemClicked\(mode, item\)/);
  assert.match(callback, /callback.onDestroyActionMode\(mode\)/);
  assert.match(callback, /callback\).onGetContentRect\(mode, view, rect\)/);
  assert.doesNotMatch(callback, /\.finish\(|\.hide\(|removeAllRanges/);
});

test('only reader WebViews receive blue native handles before selection begins', () => {
  const patch = read('android/modu_reader_selection.gradle');
  assert.match(patch, /super\(moduReaderContext\(context, customSettings, contextMenu\), containerView/);
  assert.match(patch, /if \(settings.disableContextMenu \|\| menu == null\) return context;/);
  assert.match(patch, /new android.view.ContextThemeWrapper\(context, R.style.ModuReaderSelection\)/);
  assert.match(patch, /main.res.srcDir\(rootProject.file\('reader-selection-res'\)\)/);
  const styles = read('android/reader-selection-res/values/styles.xml');
  for (const name of ['textSelectHandle', 'textSelectHandleLeft', 'textSelectHandleRight'])
    assert.match(styles, new RegExp(`android:${name}">@drawable/modu_selection_handle`));
  assert.match(read('android/reader-selection-res/drawable/modu_selection_handle.xml'), /#1976D2/);
  assert.doesNotMatch(read('android/app/src/main/res/values/styles.xml'), /textSelectHandle/,
    'do not recolor every native control or mutate the Activity theme');
});
