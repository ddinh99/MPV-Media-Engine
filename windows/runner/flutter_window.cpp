#include "flutter_window.h"

#include <optional>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <dxgi1_6.h>
#include <wrl/client.h>

#include "flutter/generated_plugin_registrant.h"

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

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  // Register platform method channel for HDR detection
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.mpv_media_engine/platform",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "isWindowsHdrEnabled") {
          bool hdrEnabled = false;
          Microsoft::WRL::ComPtr<IDXGIFactory1> factory;
          if (SUCCEEDED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) {
            Microsoft::WRL::ComPtr<IDXGIAdapter1> adapter;
            for (UINT i = 0; factory->EnumAdapters1(i, &adapter) != DXGI_ERROR_NOT_FOUND; ++i) {
              Microsoft::WRL::ComPtr<IDXGIOutput> output;
              for (UINT j = 0; adapter->EnumOutputs(j, &output) != DXGI_ERROR_NOT_FOUND; ++j) {
                Microsoft::WRL::ComPtr<IDXGIOutput6> output6;
                if (SUCCEEDED(output.As(&output6))) {
                  DXGI_OUTPUT_DESC1 desc1;
                  if (SUCCEEDED(output6->GetDesc1(&desc1))) {
                    if (desc1.ColorSpace == DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020) {
                      hdrEnabled = true;
                    }
                  }
                }
                output.Reset();
              }
              adapter.Reset();
            }
          }
          result->Success(flutter::EncodableValue(hdrEnabled));
        } else if (call.method_name() == "getDisplayMaxLuminance") {
          // MaxLuminance from DXGI_OUTPUT_DESC1 (nits, from the display's
          // EDID/DisplayID). Prefer an output currently in HDR mode; fall
          // back to the brightest output otherwise. 0.0 = unknown.
          double maxLuminance = 0.0;
          double hdrOutputLuminance = 0.0;
          Microsoft::WRL::ComPtr<IDXGIFactory1> factory;
          if (SUCCEEDED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) {
            Microsoft::WRL::ComPtr<IDXGIAdapter1> adapter;
            for (UINT i = 0; factory->EnumAdapters1(i, &adapter) != DXGI_ERROR_NOT_FOUND; ++i) {
              Microsoft::WRL::ComPtr<IDXGIOutput> output;
              for (UINT j = 0; adapter->EnumOutputs(j, &output) != DXGI_ERROR_NOT_FOUND; ++j) {
                Microsoft::WRL::ComPtr<IDXGIOutput6> output6;
                if (SUCCEEDED(output.As(&output6))) {
                  DXGI_OUTPUT_DESC1 desc1;
                  if (SUCCEEDED(output6->GetDesc1(&desc1))) {
                    if (desc1.MaxLuminance > maxLuminance) {
                      maxLuminance = desc1.MaxLuminance;
                    }
                    if (desc1.ColorSpace == DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020 &&
                        desc1.MaxLuminance > hdrOutputLuminance) {
                      hdrOutputLuminance = desc1.MaxLuminance;
                    }
                  }
                }
                output.Reset();
              }
              adapter.Reset();
            }
          }
          result->Success(flutter::EncodableValue(
              hdrOutputLuminance > 0.0 ? hdrOutputLuminance : maxLuminance));
        } else {
          result->NotImplemented();
        }
      });

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
