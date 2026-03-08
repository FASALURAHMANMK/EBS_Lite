#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {
// Best-effort: opt into Per-Monitor V2 DPI awareness at runtime. This prevents
// OS bitmap scaling, which makes text look blurry/outlined on desktop at
// non-100% scaling.
void EnsurePerMonitorDpiAwareness() {
  HMODULE user32 = ::LoadLibraryW(L"User32.dll");
  if (!user32) {
    return;
  }

  using SetDpiAwarenessContextFn = BOOL(WINAPI*)(DPI_AWARENESS_CONTEXT);
  auto set_ctx = reinterpret_cast<SetDpiAwarenessContextFn>(
      ::GetProcAddress(user32, "SetProcessDpiAwarenessContext"));
  if (set_ctx != nullptr) {
    set_ctx(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  }

  ::FreeLibrary(user32);
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  EnsurePerMonitorDpiAwareness();

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"EBS Lite", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
