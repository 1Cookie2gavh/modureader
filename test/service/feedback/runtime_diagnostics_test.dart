import 'package:anx_reader/service/feedback/runtime_diagnostics.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('only fixed states/numeric diagnostics, bounded and reset every start',
      () {
    RuntimeDiagnostics.start('1.2.9+10127');
    RuntimeDiagnostics.record(RuntimeEvent.reader,
        state: 'private book /secret?key=SECRET');
    RuntimeDiagnostics.record(RuntimeEvent.syncComplete, durationMs: 125);
    expect(RuntimeDiagnostics.preview(), contains('125'));
    expect(RuntimeDiagnostics.preview(), isNot(contains('SECRET')));
    for (var i = 0; i < 400; i++) {
      RuntimeDiagnostics.record(RuntimeEvent.ttsPause);
    }
    expect('"event"'.allMatches(RuntimeDiagnostics.preview()).length, 300);
    RuntimeDiagnostics.start('1.2.9+10127');
    expect(RuntimeDiagnostics.preview(), isNot(contains('ttsPause')));
    expect(RuntimeDiagnostics.preview(), contains('sessionStart'));
  });

  test('ordinary local logs also default to clearing on restart', () async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    expect(Prefs().clearLogWhenStart, isTrue);
  });
}
