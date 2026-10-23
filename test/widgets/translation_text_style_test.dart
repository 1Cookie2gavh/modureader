import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/translation_text_style.dart';
import 'package:anx_reader/service/config_transfer/settings_modules.dart';
import 'package:anx_reader/service/config_transfer/settings_value_validation.dart';
import 'package:anx_reader/widgets/settings/translation_text_style_settings.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });
  test(
      'appearance is portable and validates fonts/numbers without changing source',
      () {
    final style = TranslationTextStyle.decode(
        '{"font":"测试 字体.ttf","size":28,"bold":true,"italic":true}');
    expect(
        TranslationTextStyle.decode(style.encode()).textStyle, style.textStyle);
    expect(style.textStyle.fontWeight, FontWeight.bold);
    expect(style.webStyle(1234)['fontUrl'], contains('127.0.0.1:1234/fonts/'));
    expect(
        TranslationTextStyle.decode('{"font":"../a.ttf","size":999}').font, '');
    expect(TranslationTextStyle.decode('{"size":999}').size, 48);
    expect(TranslationTextStyle.decode('broken').size, 0);
    for (final key in [
      'classicalTranslationTextStyle',
      'languageTranslationTextStyle'
    ]) {
      expect(settingsModuleForKey(key), 'translation');
      validateSettingsValue(key, style.encode());
      expect(() => validateSettingsValue(key, '{"font":"../a.ttf"}'),
          throwsFormatException);
    }
  });
  for (final classical in [true, false]) {
    final prefix = classical ? 'classical' : 'language';
    testWidgets(
        '$prefix appearance persists independently and previews only output',
        (tester) async {
      const otherStyle =
          '{"font":"serif","size":36,"bold":false,"italic":false}';
      if (classical) {
        Prefs().languageTranslationTextStyle = otherStyle;
      } else {
        Prefs().classicalTranslationTextStyle = otherStyle;
      }
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TranslationTextStyleSettings(classical: classical)))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('$prefix-style-font')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monospace'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('$prefix-style-size')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('18 px'));
      await tester.pumpAndSettle();
      for (final name in ['bold', 'italic']) {
        final row = find.byKey(ValueKey('$prefix-style-$name'));
        await tester.ensureVisible(row);
        await tester
            .tap(find.descendant(of: row, matching: find.byType(Switch)));
        await tester.pumpAndSettle();
      }
      final style = TranslationTextStyle.decode(classical
          ? Prefs().classicalTranslationTextStyle
          : Prefs().languageTranslationTextStyle);
      expect(style.font, 'monospace');
      expect(style.size, 18);
      expect(style.bold, true);
      expect(style.italic, true);
      expect(
          Prefs().prefs.getKeys(), contains('${prefix}TranslationTextStyle'));
      expect(
          classical
              ? Prefs().languageTranslationTextStyle
              : Prefs().classicalTranslationTextStyle,
          otherStyle);
      expect(Prefs().prefs.get('readStyle'), isNull);
      expect(
          tester
              .widget<Text>(find.byKey(ValueKey('$prefix-style-preview')))
              .style,
          style.textStyle);
      expect(tester.takeException(), isNull);
    });
  }
}
