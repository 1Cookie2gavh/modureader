import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/models/custom_css_profile.dart';
import 'package:anx_reader/service/book_player/document_reading_mode_store.dart';
import 'package:anx_reader/service/book_player/document_type_store.dart';
import 'package:anx_reader/utils/color_scheme.dart';
import 'package:anx_reader/widgets/bookshelf/book_type_badges.dart';
import 'package:anx_reader/widgets/bookshelf/book_item.dart';
import 'package:anx_reader/service/knowledge/book_knowledge_index_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });
  Book book(String extension) =>
      Book.mock()..filePath = 'file/example.$extension';
  testWidgets(
      'format and indexed labels toggle independently and remember choice',
      (tester) async {
    expect(Prefs().showBookIndexBadge, isTrue);
    expect(Prefs().showBookFormatBadge, isTrue);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      BookTypeBadges(book: book('epub')),
      const KnowledgeStatusBadge(indexed: true, item: null),
    ]))));
    await tester.pump();
    expect(find.text('EPUB'), findsOneWidget);
    expect(find.text('Indexed'), findsOneWidget);
    Prefs().showBookIndexBadge = false;
    await tester.pump();
    expect(find.text('Indexed'), findsNothing);
    expect(find.text('EPUB'), findsOneWidget);
    Prefs().showBookFormatBadge = false;
    Prefs().showBookIndexBadge = true;
    await tester.pump();
    expect(find.text('Indexed'), findsOneWidget);
    expect(find.text('EPUB'), findsNothing);
    Prefs().showBookIndexBadge = false;
    await tester.pump();
    await Prefs().initPrefs();
    expect(Prefs().showBookIndexBadge, isFalse);
    expect(Prefs().showBookFormatBadge, isFalse);
  });

  testWidgets('indexed and format labels share font, padding and height',
      (tester) async {
    for (final eink in [false, true]) {
      Prefs().eInkMode = eink;
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => Theme(
              data: colorSchema(Prefs(), context, Brightness.light),
              child: child!),
          home: Scaffold(
              body: Column(children: [
        BookTypeBadges(book: book('epub')),
        const KnowledgeStatusBadge(indexed: true, item: null),
      ]))));
      await tester.pump();
      final format = tester.widget<Text>(find.text('EPUB')).style!;
      final indexed = tester.widget<Text>(find.text('Indexed')).style!;
      expect(indexed.fontSize, format.fontSize);
      expect(indexed.height, format.height);
      expect(indexed.fontWeight, format.fontWeight);
      final formatBox = find
          .ancestor(of: find.text('EPUB'), matching: find.byType(DecoratedBox))
          .first;
      final indexBox = find
          .ancestor(
              of: find.text('Indexed'), matching: find.byType(DecoratedBox))
          .first;
      expect(tester.getSize(indexBox).height, tester.getSize(formatBox).height);
      for (final label in ['EPUB', 'Indexed']) {
        final padding = tester.widget<Padding>(find
            .ancestor(of: find.text(label), matching: find.byType(Padding))
            .first);
        expect(padding.padding,
            const EdgeInsets.symmetric(horizontal: 6, vertical: 3));
      }
    }
  });

  testWidgets('hiding indexed labels retains progress and failure notices',
      (tester) async {
    Prefs().showBookIndexBadge = false;
    for (final status in BookKnowledgeQueueStatus.values) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: KnowledgeStatusBadge(
        indexed: true,
        item: BookKnowledgeQueueItem(
            book: book('epub'), status: status, requestedAt: DateTime(2026)),
      ))));
      final hidden = status == BookKnowledgeQueueStatus.completed ||
          status == BookKnowledgeQueueStatus.cancelled;
      expect(find.byType(Text), hidden ? findsNothing : findsOneWidget,
          reason: status.name);
    }
  });
  test('format uses case-insensitive container extension, not title', () {
    for (final extension in [
      'PDF',
      'epub',
      'fb2',
      'txt',
      'mobi',
      'azw3',
      'md',
      'umd'
    ]) {
      expect(
          BookTypeBadges.formatFor(book(extension)), extension.toUpperCase());
    }
    expect(BookTypeBadges.formatFor(book('markdown')), 'MD');
    expect(BookTypeBadges.formatFor(Book.mock()), '');
  });
  test(
      'PDF alone is not proof of scanning; cached evidence and correction decide',
      () async {
    final pdf = book('pdf'), store = DocumentTypeStore(Prefs().prefs);
    final key = customCssBookKey(pdf);
    expect(BookTypeBadges.scanned(pdf), false);
    await store.saveDetected(key, 'scanned');
    expect(BookTypeBadges.scanned(pdf), true);
    await store.save(key, 'text');
    expect(BookTypeBadges.scanned(pdf), false);
    await store.save(key, null);
    expect(BookTypeBadges.scanned(pdf), true);
  });
  test(
      'image EPUB/MOBI/AZW3/FB2 use existing import evidence and manual switch',
      () async {
    for (final extension in ['epub', 'mobi', 'azw3', 'fb2']) {
      final value = book(extension),
          store = DocumentReadingModeStore(Prefs().prefs);
      expect(BookTypeBadges.scanned(value), false);
      await store.setScanned(value, true);
      expect(BookTypeBadges.scanned(value), true,
          reason: 'manual scanned overrides automatic ordinary detection');
      await store.save(value, 'standard');
      expect(BookTypeBadges.scanned(value), true,
          reason: 'later detection must preserve the manual choice');
      await store.save(value, 'image-epub');
      expect(BookTypeBadges.scanned(value), true);
      await store.setScanned(value, false);
      expect(BookTypeBadges.scanned(value), false);
    }
  });
  testWidgets(
      'narrow labels wrap without overflow, use black and white in E-Ink',
      (tester) async {
    final value = book('epub');
    await tester.runAsync(() =>
        DocumentReadingModeStore(Prefs().prefs).save(value, 'image-epub'));
    for (final eink in [false, true]) {
      Prefs().eInkMode = eink;
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => Theme(
              data: colorSchema(Prefs(), context, Brightness.light),
              child: child!),
          home: Scaffold(
              body: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: SizedBox(
                      width: 65, child: BookTypeBadges(book: value))))));
      await tester.pump();
      expect(find.text('EPUB'), findsOneWidget);
      expect(find.text('Scanned'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.text('Scanned')).dy,
          lessThan(tester.getTopLeft(find.text('EPUB')).dy));
      final label = tester.widget<Text>(find.text('EPUB'));
      expect(label.style!.color, eink ? Colors.black : Colors.white);
    }
    await tester.runAsync(
        () => DocumentReadingModeStore(Prefs().prefs).setScanned(value, false));
    Prefs().notifyExternalChange();
    await tester.pump();
    expect(find.text('Scanned'), findsNothing);
    expect(find.text('EPUB'), findsOneWidget);
    await tester.runAsync(
        () => DocumentReadingModeStore(Prefs().prefs).setScanned(value, true));
    Prefs().notifyExternalChange();
    await tester.pump();
    expect(find.text('Scanned'), findsOneWidget);
    Prefs().showBookFormatBadge = false;
    await tester.pump();
    expect(find.text('EPUB'), findsNothing);
    expect(find.text('Scanned'), findsOneWidget);
    await tester.runAsync(
        () => DocumentReadingModeStore(Prefs().prefs).setScanned(value, false));
    Prefs().notifyExternalChange();
    await tester.pump();
    expect(find.text('EPUB'), findsNothing);
    expect(find.text('Scanned'), findsNothing);
    Prefs().showBookFormatBadge = true;
    await tester.pump();
    expect(find.text('EPUB'), findsOneWidget);
  });
}
