#include "flutter_window.h"

#include <dwmapi.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// DWMWA_BORDER_COLOR is Windows 11 only and not in every SDK's headers.
constexpr DWORD kDwmwaBorderColor = 34;
// Sentinel meaning "draw no border".
constexpr COLORREF kDwmwaColorNone = 0xFFFFFFFE;

enum AccentState {
  ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
};

struct AccentPolicy {
  int accent_state;
  int flags;
  int gradient_color;
  int animation_id;
};

struct WindowCompositionAttributeData {
  int attribute;
  void* data;
  unsigned long data_size;
};

// Windows 11 draws a one-pixel border around every top-level window, in the
// compositor rather than in the client area, which shows as an outline around
// a frameless window. Nothing in the Flutter layer can remove it.
void RemoveDwmBorder(HWND hwnd) {
  const COLORREF none = kDwmwaColorNone;
  DwmSetWindowAttribute(hwnd, kDwmwaBorderColor, &none, sizeof(none));

  // Also ask for the dark caption treatment, so any residual system chrome
  // does not flash light on launch.
  const BOOL dark = TRUE;
  DwmSetWindowAttribute(hwnd, 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */, &dark,
                        sizeof(dark));
}

// Leaves the window unfilled so the desktop shows between the cards.
//
// window_manager can do this too, but it passes flags = 2, which asks the
// compositor to draw a one-pixel border around the window. That border is the
// frame that survives every attempt to style it away, so the accent is set
// here with flags = 0 instead. This runs before the window is shown; applying
// it afterwards lets the compositor draw its own chrome over the top.
void MakeWindowTransparent(HWND hwnd) {
  const HINSTANCE user32 = LoadLibraryW(L"user32.dll");
  if (user32 == nullptr) {
    return;
  }

  using SetWindowCompositionAttributeFn =
      BOOL(WINAPI*)(HWND, WindowCompositionAttributeData*);
  const auto set_composition =
      reinterpret_cast<SetWindowCompositionAttributeFn>(
          GetProcAddress(user32, "SetWindowCompositionAttribute"));

  if (set_composition != nullptr) {
    AccentPolicy policy = {};
    policy.accent_state = ACCENT_ENABLE_TRANSPARENTGRADIENT;
    policy.flags = 0;
    policy.gradient_color = 0;

    WindowCompositionAttributeData data = {};
    data.attribute = 19;  // WCA_ACCENT_POLICY
    data.data = &policy;
    data.data_size = sizeof(policy);

    set_composition(hwnd, &data);
  }

  FreeLibrary(user32);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Both before the window is shown. Applying them afterwards lets the
  // compositor draw its own chrome over the top of them.
  RemoveDwmBorder(GetHandle());
  MakeWindowTransparent(GetHandle());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
