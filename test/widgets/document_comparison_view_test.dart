import 'package:anx_reader/widgets/reading_page/document_comparison_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reader extends StatefulWidget {
  const _Reader({super.key});
  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> {
  int value = 0;
  @override
  Widget build(BuildContext context) => SizedBox.expand(
      child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => value++),
          child: Text('$value')));
}

void main() {
  testWidgets(
      'portrait and landscape split evenly, retain both readers and route input',
      (tester) async {
    final original = GlobalKey<_ReaderState>();
    final reflow = GlobalKey<_ReaderState>();
    var originalInput = 0, reflowInput = 0;
    Future<void> show(Size size,
        {bool compare = true, bool showReflow = true}) async {
      tester.view.reset();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: DocumentComparisonView(
          compare: compare,
          onOriginalInteraction: () => originalInput++,
          onReflowInteraction: () => reflowInput++,
          original: _Reader(key: original),
          reflow: showReflow ? _Reader(key: reflow) : null,
        ),
      )));
      await tester.pump();
    }

    addTearDown(tester.view.reset);
    await show(const Size(400, 800));
    final originalState = original.currentState;
    final reflowState = reflow.currentState;
    var a = tester.getRect(find.byKey(original));
    var b = tester.getRect(find.byKey(reflow));
    expect(a, const Rect.fromLTWH(0, 0, 400, 399.5));
    expect(b, const Rect.fromLTWH(0, 400.5, 400, 399.5));
    await tester.tapAt(a.center);
    await tester.tapAt(b.center);
    await tester.pump();
    expect(originalInput, 1);
    expect(reflowInput, 1);
    expect(originalState!.value, 1);
    expect(reflowState!.value, 1);

    await show(const Size(800, 400));
    a = tester.getRect(find.byKey(original));
    b = tester.getRect(find.byKey(reflow));
    expect(a, const Rect.fromLTWH(0, 0, 399.5, 400));
    expect(b, const Rect.fromLTWH(400.5, 0, 399.5, 400));
    expect(original.currentState, same(originalState));
    expect(reflow.currentState, same(reflowState));

    await show(const Size(800, 400), compare: false);
    expect(tester.getRect(find.byKey(reflow)),
        const Rect.fromLTWH(0, 0, 800, 400));
    await tester.tapAt(const Offset(100, 100));
    await tester.pump();
    expect(originalInput, 1);
    expect(reflowInput, 2);
    expect(original.currentState, same(originalState));
    expect(reflow.currentState, same(reflowState));

    await show(const Size(400, 800));
    expect(original.currentState!.value, 1);
    expect(reflow.currentState!.value, 2);
    await tester.sendEventToBinding(const PointerScrollEvent(
        position: Offset(100, 100), scrollDelta: Offset(0, 20)));
    expect(originalInput, 2);
    expect(reflowInput, 2);
    await show(const Size(400, 800), showReflow: false);
    expect(original.currentState, same(originalState));
    expect(tester.getRect(find.byKey(original)),
        const Rect.fromLTWH(0, 0, 400, 800));
    expect(tester.takeException(), isNull);
  });
}
