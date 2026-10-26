import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/providers/book_list.dart';
import 'package:anx_reader/widgets/bookshelf/book_opened_folder.dart';
import 'package:anx_reader/widgets/bookshelf/book_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bookshelf_edit_menu_test.dart' show app;

class _Books extends BookList {
  _Books(this.entries);
  final List<Book> entries;
  @override
  Future<List<List<Book>>> build() async => [entries];
  void receive(List<Book> books) => state = AsyncData([books]);
}

Book book(int id, int clock) => Book.mock().copyWith(
    id: id,
    groupId: 2,
    filePath: 'file/$id.epub',
    coverPath: 'cover/$id.png',
    title: 'Book $id',
    readingPositionClock: clock);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
    const Size(1200, 900)
  ]) {
    testWidgets('two books reserve only two columns at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final books = [book(1, 100), book(2, 200)];
      await tester.pumpWidget(app(
          BookOpenedFolder(books: books, groupName: 'Folder'),
          books: _Books(books)));
      await tester.pumpAndSettle();
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(tester.getSize(find.byType(AlertDialog)).width,
          lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('an open folder replaces its old snapshot after sync',
      (tester) async {
    final books = [book(1, 100), book(2, 200)];
    final store = _Books(books);
    await tester.pumpWidget(
        app(BookOpenedFolder(books: books, groupName: 'Folder'), books: store));
    await tester.pumpAndSettle();
    List<Book> visible() => tester
        .widgetList<BookItem>(find.byType(BookItem))
        .map((w) => w.book)
        .toList();
    expect(visible().first.id, 2);
    store
        .receive([book(1, 300).copyWith(readingPercentage: 0.5), book(2, 200)]);
    await tester.pumpAndSettle();
    expect(visible().first.id, 1);
    expect(visible().first.readingPercentage, 0.5);
    store.receive([book(2, 200)]);
    await tester.pumpAndSettle();
    expect(visible().map((b) => b.id), [2]);
    expect(tester.takeException(), isNull);
  });
}
