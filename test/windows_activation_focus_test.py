"""Run the production WM_ACTIVATE branch with a recording SetFocus stub.

Checks message policy on macOS/Linux too; not a Windows GUI/crash reproduction.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WindowsActivationFocusTest(unittest.TestCase):
    def test_activation_matrix_and_show_desktop_restore(self):
        compiler = shutil.which('clang++') or shutil.which('g++')
        if not compiler:
            self.skipTest('C++ compiler unavailable')
        source = (ROOT / 'windows/runner/win32_window.cpp').read_text()
        branch = source.split('case WM_ACTIVATE:', 1)[1].split(
            'case WM_DWMCOLORIZATIONCOLORCHANGED:', 1)[0]
        program = r'''
#include <cstdint>
#include <initializer_list>
constexpr int WA_INACTIVE = 0, WA_ACTIVE = 1, WA_CLICKACTIVE = 2;
#define LOWORD(value) ((value) & 0xffff)
#define HIWORD(value) (((value) >> 16) & 0xffff)
int calls = 0;
void SetFocus(void*) { ++calls; }
int activate(std::uintptr_t wparam, void* child_content_) {
''' + branch + r'''
}
int main() {
  int child = 0;
  for (int state : {WA_INACTIVE, WA_ACTIVE, WA_CLICKACTIVE}) {
    for (int minimized : {0, 1, 2}) {
      for (bool has_child : {false, true}) {
        calls = 0;
        activate(state | (minimized << 16), has_child ? &child : nullptr);
        const int expected = state != WA_INACTIVE && !minimized && has_child;
        if (calls != expected) return 1;
      }
    }
  }
  calls = 0;
  activate(WA_INACTIVE, &child);
  activate(WA_INACTIVE | (1 << 16), &child);
  activate(WA_ACTIVE | (1 << 16), &child);
  if (calls != 0) return 2;
  activate(WA_ACTIVE, &child);
  if (calls != 1) return 3;
  return 0;
}
'''
        with tempfile.TemporaryDirectory(prefix='modu-focus-test-') as folder:
            cpp = Path(folder) / 'focus.cpp'
            binary = Path(folder) / 'focus-test'
            cpp.write_text(program)
            subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror',
                            str(cpp), '-o', str(binary)], check=True,
                           capture_output=True, text=True)
            subprocess.run([str(binary)], check=True, capture_output=True)


if __name__ == '__main__':
    unittest.main()
