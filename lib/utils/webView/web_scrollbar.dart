import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Future<String>? _source;

/// Decoration only: keep isolated pages bridge-free and never inspect content.
Future<void> installWebScrollbar(InAppWebViewController controller,
    {required bool reducedMotion}) async {
  try {
    final script = await (_source ??=
        rootBundle.loadString('assets/foliate-js/src/transient-scrollbar.js'));
    await controller.evaluateJavascript(source: '''
      $script
      window.__moduScrollbar?.destroy();
      window.__moduScrollbar = window.moduAttachDocumentScrollbars(document,
        {reducedMotion: () => $reducedMotion});
    ''');
  } catch (_) {
    // A navigation/disposal or a page's policy can reject decoration; keep scrolling usable.
  }
}
