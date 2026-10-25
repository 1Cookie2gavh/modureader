// Keep the bootstrap ES5-parseable so unsupported WebViews can report failure.
(function () {
  var ua = navigator.userAgent || '';
  var platform = navigator.platform || '';
  console.log('ModuUA ' + ua);
  var chromeMatch = ua.match(/Chrome\/(\d+)/);
  var chromeVersion = chromeMatch ? parseInt(chromeMatch[1], 10) : null;
  var apple = /iPad|iPhone|iPod/.test(ua) ||
    (/Mac/.test(platform) && navigator.maxTouchPoints > 1) || /Mac OS X/.test(ua);
  var importing = /[?&]importing=true(?:&|$)/.test(window.location.search);
  var failed = false;
  var loading = true;

  function fail(name, message) {
    if (failed) return;
    failed = true;
    console.error(name + ': ' + message);
    var notice = document.createElement('p');
    notice.textContent = message;
    notice.style.cssText = 'padding:24px;white-space:pre-wrap';
    document.body.appendChild(notice);
    var sent = false;
    function notify() {
      if (sent || !window.flutter_inappwebview ||
          typeof window.flutter_inappwebview.callHandler !== 'function') return;
      sent = true;
      window.removeEventListener('flutterInAppWebViewPlatformReady', notify);
      window.flutter_inappwebview.callHandler(importing ? 'onImportError' : 'onReaderLoadError',
        { name: name, message: message });
    }
    window.addEventListener('flutterInAppWebViewPlatformReady', notify);
    notify();
  }

  if (!apple && chromeVersion !== null && chromeVersion < 70) {
    fail('UnsupportedWebView', 'Android WebView ' + chromeVersion +
      ' 不受支持，需要 70 或更新版本。请更新系统 WebView 后重试。\n' +
      'Android WebView 70 or newer is required. Update the system WebView and retry.');
    return;
  }

  function scriptError() {
    if (loading) fail('ReaderScriptError',
      '阅读引擎加载失败，请检查系统 WebView 版本并导出日志。\n' +
      'Reader engine failed to load. Check the system WebView version and export logs.');
  }
  window.addEventListener('error', scriptError);

  function load(src, module) {
    return new Promise(function (resolve, reject) {
      var script = document.createElement('script');
      script.src = src;
      if (module) script.type = 'module';
      script.async = false;
      script.onload = function () { if (failed) reject(new Error('ReaderScriptError')); else resolve(); };
      script.onerror = function () { reject(new Error('ReaderScriptError')); };
      document.head.appendChild(script);
    });
  }

  // Load PDF first: book metadata extraction may start as soon as book.js runs.
  var modern = apple || (chromeVersion !== null && chromeVersion >= 100);
  load(modern ? './src/vendor/pdfjs/pdf.js' : './dist/pdf-legacy.js', false)
    .then(function () { return load(modern ? './src/book.js' : './dist/bundle.js', modern); })
    .then(function () {
      loading = false;
      window.removeEventListener('error', scriptError);
    })
    .catch(scriptError);
})();
