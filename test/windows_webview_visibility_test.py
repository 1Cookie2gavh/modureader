"""Exercise production visibility/message code with recording Win32/COM stubs.

This runs on macOS/Linux; it does not replace a Windows WebView2/RDP UI test.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / 'third_party/flutter_inappwebview_windows/windows'


def function(source, signature):
    start = source.index(signature)
    body = source.index('{', start)
    depth = 1
    end = body + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


class WindowsWebViewVisibilityTest(unittest.TestCase):
    def test_native_visibility_lifecycle(self):
        compiler = shutil.which('clang++') or shutil.which('g++')
        if not compiler:
            self.skipTest('C++ compiler unavailable')
        view = (PLUGIN / 'in_app_webview/in_app_webview.cpp').read_text()
        manager = (PLUGIN / 'in_app_webview/in_app_webview_manager.cpp').read_text()
        methods = '\n'.join([
            function(view, 'void InAppWebView::setHostWindowVisible('),
            function(view, 'bool InAppWebView::updateVisibility('),
            function(manager, 'void InAppWebViewManager::handleHostWindowMessage('),
        ])
        program = r'''
#include <cassert>
#include <cstdint>
#include <map>
#include <memory>
#include <optional>
using HWND = int;
using UINT = unsigned;
using WPARAM = std::uintptr_t;
using LPARAM = std::intptr_t;
constexpr UINT WM_SIZE = 1, WM_SHOWWINDOW = 2, WM_WINDOWPOSCHANGED = 3;
constexpr UINT SIZE_MINIMIZED = 1, SWP_HIDEWINDOW = 0x80;
constexpr int FALSE = 0;
struct WINDOWPOS { UINT flags; };
bool window_visible = true, minimized = false;
bool IsWindowVisible(HWND) { return window_visible; }
bool IsIconic(HWND) { return minimized; }
bool succeededOrLog(int result) { return result == 0; }
struct Controller {
  int calls = 0;
  bool visible = true, fail = false;
  int put_IsVisible(bool value) {
    ++calls;
    if (fail) return -1;
    visible = value;
    return 0;
  }
};
struct InAppWebView {
  std::shared_ptr<Controller> webViewController = std::make_shared<Controller>();
  bool hostWindowVisible_ = true, paused_ = false;
  std::optional<bool> controllerVisible_;
  void setHostWindowVisible(bool visible);
  bool updateVisibility();
};
struct PlatformView { std::shared_ptr<InAppWebView> view; };
struct InAppWebViewManager {
  std::map<int, std::unique_ptr<PlatformView>> webViews, keepAliveWebViews;
  void handleHostWindowMessage(HWND, UINT, WPARAM, LPARAM);
};
''' + methods + r'''
int main() {
  InAppWebViewManager manager;
  auto normal = std::make_shared<InAppWebView>();
  auto retained = std::make_shared<InAppWebView>();
  manager.webViews[1] = std::make_unique<PlatformView>(PlatformView{normal});
  manager.keepAliveWebViews[1] = std::make_unique<PlatformView>(PlatformView{retained});
  manager.webViews[2] = nullptr;
  manager.webViews[3] = std::make_unique<PlatformView>();
  auto check = [&](bool expected) {
    assert(normal->webViewController->visible == expected);
    assert(retained->webViewController->visible == expected);
  };
  for (int i = 0; i < 100; ++i) {
    minimized = true;
    manager.handleHostWindowMessage(1, WM_SIZE, SIZE_MINIMIZED, 0);
    check(false);
    manager.handleHostWindowMessage(1, WM_SHOWWINDOW, 1, 0);
    check(false); // Showing an iconic owner must not restore its WebViews.
    minimized = false;
    manager.handleHostWindowMessage(1, WM_SIZE, 0, 0);
    check(true);
    manager.handleHostWindowMessage(1, WM_SHOWWINDOW, 0, 0);
    check(false); // The WS_VISIBLE bit can still be set during this message.
    window_visible = false;
    manager.handleHostWindowMessage(1, WM_SIZE, 0, 0);
    check(false);
    manager.handleHostWindowMessage(1, WM_SHOWWINDOW, 1, 0);
    check(true); // Restore before the visibility style is updated.
    window_visible = true;
  }
  WINDOWPOS pos{SWP_HIDEWINDOW};
  manager.handleHostWindowMessage(1, WM_WINDOWPOSCHANGED, 0,
      reinterpret_cast<LPARAM>(&pos));
  check(false);
  manager.handleHostWindowMessage(1, WM_WINDOWPOSCHANGED, 0, 0);
  check(true);
  const auto calls = normal->webViewController->calls;
  manager.handleHostWindowMessage(1, WM_WINDOWPOSCHANGED, 0, 0);
  manager.handleHostWindowMessage(1, 999, 0, 0);
  assert(normal->webViewController->calls == calls);
  normal->paused_ = true;
  assert(normal->updateVisibility());
  manager.handleHostWindowMessage(1, WM_SHOWWINDOW, 0, 0);
  manager.handleHostWindowMessage(1, WM_SHOWWINDOW, 1, 0);
  assert(!normal->webViewController->visible); // Don't undo explicit pause.
  manager.handleHostWindowMessage(1, WM_SHOWWINDOW, 0, 0);
  normal->paused_ = false;
  assert(normal->updateVisibility());
  check(false); // Resume while hidden must not reveal the native window.
  manager.handleHostWindowMessage(1, WM_SHOWWINDOW, 1, 0);
  check(true);
  normal->webViewController->fail = true;
  normal->setHostWindowVisible(false);
  normal->webViewController->fail = false;
  normal->setHostWindowVisible(false); // A failed COM call must be retried.
  assert(!normal->webViewController->visible);
  normal->webViewController.reset();
  normal->setHostWindowVisible(true); // Disposal / missing controller is safe.
}
'''
        with tempfile.TemporaryDirectory(prefix='modu-webview-visibility-') as folder:
            cpp = Path(folder) / 'visibility.cpp'
            binary = Path(folder) / 'visibility-test'
            cpp.write_text(program)
            subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror',
                            str(cpp), '-o', str(binary)], check=True,
                           capture_output=True, text=True)
            subprocess.run([str(binary)], check=True, capture_output=True)

    def test_wiring_creation_and_explicit_pause(self):
        plugin = (PLUGIN / 'flutter_inappwebview_windows_plugin.cpp').read_text()
        self.assertIn('inAppWebViewManager->handleHostWindowMessage(', plugin)
        view = (PLUGIN / 'in_app_webview/in_app_webview.cpp').read_text()
        creation = function(view, 'bool InAppWebView::createSurface(')
        self.assertIn('GetAncestor(', creation)
        self.assertIn('GA_ROOT', creation)
        self.assertIn('IsWindowVisible(', creation)
        self.assertIn('!IsIconic(', creation)
        self.assertIn('setHostWindowVisible(', creation)
        self.assertNotIn('webViewController->put_IsVisible(true)', creation)
        for name, assignment in [('pause', 'paused_ = true'),
                                 ('resume', 'paused_ = false')]:
            body = function(view, f'void InAppWebView::{name}(')
            self.assertIn(assignment, body)
            self.assertIn('updateVisibility()', body)
            self.assertNotIn('put_IsVisible(true)', body)


if __name__ == '__main__':
    unittest.main()
