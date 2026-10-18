import 'package:anx_reader/widgets/reading_page/pdf_zoom_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'zoom bar drags, is 80 percent transparent and hides after five idle seconds',
      (tester) async {
    final zoom = ValueNotifier<double>(1);
    addTearDown(zoom.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PdfZoomToolbar(
                zoom: zoom,
                change: (value, _) async {
                  zoom.value = value;
                }))));
    final label = find.text('1.0×');
    final before = tester.getCenter(label);
    final background = tester.widget<Material>(
        find.ancestor(of: label, matching: find.byType(Material)).first);
    expect(background.color!.a, closeTo(.2, .01));
    await tester.drag(label, const Offset(100, -150));
    await tester.pump();
    expect(tester.getCenter(label).dy, lessThan(before.dy));
    await tester.pump(const Duration(seconds: 4));
    expect(label, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(label, findsNothing);
    zoom.value = 2;
    await tester.pump();
    expect(find.text('2.0×'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('floating zoom clamps, resets and does not block page touches',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final zoom = ValueNotifier<double>(1);
    addTearDown(zoom.dispose);
    final calls = <(double, bool)>[];
    var pageTaps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Stack(children: [
      Positioned.fill(
          child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: () => pageTaps++)),
      Positioned.fill(
          child: PdfZoomToolbar(
              zoom: zoom,
              change: (v, reset) async {
                calls.add((v, reset));
                zoom.value = v;
              })),
    ]))));
    await tester.tapAt(const Offset(100, 100));
    expect(pageTaps, 1);
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(zoom.value, 1.25);
    zoom.value = 4;
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
            .onPressed,
        isNull);
    await tester.tap(find.byTooltip('Reset zoom (keep crop)'));
    await tester.pumpAndSettle();
    expect(calls.last, (1.0, true));
    await tester.tap(find.byTooltip('Hide zoom'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Zoom in'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
