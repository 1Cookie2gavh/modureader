import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final page = File('lib/page/reading_page.dart').readAsStringSync();
  final player =
      File('lib/page/book_player/epub_player.dart').readAsStringSync();

  test('relocation notifies metadata without rebuilding the native reader', () {
    final relocate = player
        .split("handlerName: 'onRelocated'")
        .last
        .split("handlerName: 'onTtsChapter'")
        .first;
    expect(relocate, isNot(contains('setState(')));
    expect(relocate, contains('readingProgress.value = ReaderProgress('));
    expect(relocate, contains('widget.updateParent()'));
    // Keep progress persistence, PDF comparison and E-Ink refresh intact.
    expect(relocate, contains('_recordReadingAction('));
    expect(relocate, contains('originalDocumentPageChanged('));
    expect(relocate, contains('_observeEinkPage(location)'));
    expect(player, contains('valueListenable: readingProgress'));
    expect(player, contains('builder: (_, __, ___) => readingInfoWidget()'));
  });

  test('bookmark refresh is local; initial/document mode change still rebuilds',
      () {
    final update =
        page.split('void updateState()').last.split('@override').first;
    expect(update, contains('_bookmarkExists.value = player.bookmarkExists'));
    expect(update,
        contains('if (_documentImages != player.supportsDocumentImages)'));
    expect(page, contains('bool? _documentImages;'));
    expect(page, contains('valueListenable: _bookmarkExists'));
  });

  test(
      'repeated menu visibility avoids rebuild but hidden close restores focus',
      () {
    final show = page
        .split('void showBottomBar()')
        .last
        .split('void hideBottomBar()')
        .first;
    final hide = page
        .split('void hideBottomBar()')
        .last
        .split('void showOrHideAppBarAndBottomBar')
        .first;
    expect(show, contains('if (!mounted || !bottomBarOffstage) return;'));
    expect(hide,
        contains('if (!bottomBarOffstage || !identical(_currentPage, empty))'));
    expect(hide.indexOf('_requestReaderFocus();'),
        greaterThan(hide.indexOf('});')));
    expect(page, contains('late final EpubPlayer _player = EpubPlayer('));
    expect(page, contains('child: _player,'));
  });
}
