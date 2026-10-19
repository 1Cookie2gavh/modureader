import 'package:anx_reader/widgets/reading_page/widget_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('submenu changes only title font: $brightness', (tester) async {
      late TextStyle base;
      late TextStyle heading;
      late TextStyle body;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness, fontFamily: 'Roboto'),
        home: Builder(builder: (context) {
          base = Theme.of(context).textTheme.titleLarge!;
          body = Theme.of(context).textTheme.bodyMedium!;
          heading = readerSubmenuTitleStyle(context)!;
          return Scaffold(body: Column(children: [
            widgetTitle('Existing title', null),
            Text('Submenu', style: heading),
            const Text('Option description'),
          ]));
        }),
      ));
      expect(heading, base.copyWith(fontFamily: 'SourceHanSerif'));
      expect(body.fontFamily, 'Roboto');
      final oldTitle = tester.widget<Text>(find.text('Existing title'));
      expect(oldTitle.style, const TextStyle(
        fontSize: 28, fontFamily: 'SourceHanSerif', fontWeight: FontWeight.bold,
      ));
      expect(tester.takeException(), isNull);
    });
  }
}
