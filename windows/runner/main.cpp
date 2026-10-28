#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <algorithm>
#include <cctype>
#include "app_links/app_links_plugin_c_api.h"

#include "flutter_window.h"
#include "utils.h"
#include "native_crash_recorder.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  // Forward local documents and reading links to the existing database owner.
  auto is_open_request = [](const std::string& value) {
    if (value.rfind("modu://read?", 0) == 0) return true;
    const bool local = value.rfind("file:", 0) == 0 ||
      (value.size() > 2 && value[1] == ':') || value.rfind("\\\\", 0) == 0;
    if (!local) return false;
    auto dot = value.find_last_of('.');
    if (dot == std::string::npos) return false;
    auto ext = value.substr(dot + 1);
    std::transform(ext.begin(), ext.end(), ext.begin(),
      [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    const std::vector<std::string> supported = {"epub", "mobi", "azw3", "fb2", "txt", "pdf", "md", "markdown", "umd"};
    return std::find(supported.begin(), supported.end(), ext) != supported.end();
  };
  if (std::any_of(command_line_arguments.begin(), command_line_arguments.end(), is_open_request)) {
    HWND existing = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Modu");
    if (existing != nullptr) {
      for (const auto& value : command_line_arguments) {
        if (!is_open_request(value)) continue;
        // app_links 6.4.1's WM_COPYDATA message carries UTF-8, including paths.
        COPYDATASTRUCT data = {};
        data.dwData = WM_USER + 2;
        data.cbData = static_cast<DWORD>(value.size() + 1);
        data.lpData = const_cast<char*>(value.c_str());
        ::SendMessage(existing, WM_COPYDATA, reinterpret_cast<WPARAM>(existing),
                      reinterpret_cast<LPARAM>(&data));
      }
      if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
      return EXIT_SUCCESS;
    }
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  InitializeNativeCrashRecorder();

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Modu", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // window_manager.destroy posts WM_QUIT without destroying the window.
  // Release Flutter/WebView2 COM resources while the STA is still alive,
  // rather than from the local window's destructor after CoUninitialize.
  window.Destroy();
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
