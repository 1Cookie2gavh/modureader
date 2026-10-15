import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/widgets/reading_page/document_reader_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });
  for (final size in [
    const Size(320, 740),
    const Size(844, 390),
    const Size(1440, 900)
  ]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('menus overlay stable text and fit 80% at $size / $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var closed = 0;
        await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: DocumentReaderSurface(
              onBack: () => closed++,
              header: const Text('Header'),
              body: const SizedBox.expand(key: ValueKey('stable-body')),
              navigation: const SizedBox(height: 48, child: Text('1 / 10')),
              tools: const Text('Short tools'),
              style: SingleChildScrollView(
                  child: Column(
                      children: List.generate(60, (i) => Text('Setting $i')))),
              brightness: const Text('Brightness'),
              narration: const Text('Narration'),
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.toc)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.edit))
              ],
            ))));
        final body = tester.getRect(find.byKey(const ValueKey('stable-body')));
        await tester.tap(find.byKey(const ValueKey('document-tools-menu')));
        await tester.pumpAndSettle();
        final shortHeight = tester.getSize(find.byType(BottomSheet)).height;
        expect(shortHeight, lessThan(size.height * .5));
        expect(tester.getRect(find.byKey(const ValueKey('stable-body'))), body);
        expect(find.text('Header').hitTestable(), findsNothing);
        await tester.tap(find.byKey(const ValueKey('document-style-menu')));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(BottomSheet)).height + 96,
            lessThanOrEqualTo(size.height * .8 + .01));
        expect(tester.getRect(find.byKey(const ValueKey('stable-body'))), body);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(closed, 0);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(closed, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
