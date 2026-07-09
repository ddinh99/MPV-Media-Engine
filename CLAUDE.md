# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MPV Media Engine (package name `mvp_sound_engine`) is a Flutter Windows desktop app that acts as a real-time control surface for the [MPV media player](https://mpv.io/). It never edits MPV's config files — instead it pushes property/filter changes live over MPV's JSON IPC, so shaders, HDR tone mapping, scalers, and FFmpeg audio DSP chains (EQ, compressor, DynAudNorm, pan/downmix, ambience) all update instantly while a video is already playing.

## Build & Run Commands

Flutter is **not** on PATH — always use the full path: `c:\Users\Dai\dev\flutter\bin\flutter.bat`.

- Build (verify compiles): `c:\Users\Dai\dev\flutter\bin\flutter.bat build windows`
- Analyze/lint: `c:\Users\Dai\dev\flutter\bin\flutter.bat analyze`
- Run all tests: `c:\Users\Dai\dev\flutter\bin\flutter.bat test`
- Run a single test file: `c:\Users\Dai\dev\flutter\bin\flutter.bat test test/preferences_test.dart`
- Release output lands in `build\windows\x64\runner\Release\`

### Critical rules for running/building (do not violate)
1. **Never run `flutter run` yourself** (directly or via a background tool) for this Windows desktop app — the GUI launches invisibly in the background session and you can't interact with or verify it. Always ask the user to run it themselves, or tell them to double-click `run_app.bat`.
2. **Always ensure zombie processes are killed before building or running.** `MPV_Sound_Engine.exe`/`MPV_Media_Engine.exe` and `dart.exe` frequently stay alive and lock the executable, causing `LNK1168` link errors. `run_app.bat` already does this cleanup (`taskkill /F /IM ...`) before invoking `flutter run`.
3. **If you need to verify the app builds, use `flutter build windows` only** — do not run the resulting executable yourself.

## Architecture

### Provider / state layering
The app uses `provider` (`ChangeNotifier`) for state, wired up in [lib/app.dart](lib/app.dart):
- `DspProvider` — owns the audio DSP state (`DspState` in [lib/models/dsp_state.dart](lib/models/dsp_state.dart)) and the single `MpvIpcService` connection. It's the only provider that actually owns the IPC socket.
- `VideoProvider(DspProvider)` — owns video/shader/HDR state (`VideoState` in [lib/models/video_state.dart](lib/models/video_state.dart)) but has **no IPC connection of its own** — it sends every command through `dspProvider.sendRawCommand(...)`, so `DspProvider` must be constructed first.
- `ThemeProvider` — light/dark theme toggle, persisted via `PreferencesService`.

Widgets under [lib/widgets/tab_*.dart](lib/widgets) each correspond to one tab in [lib/screens/home_screen.dart](lib/screens/home_screen.dart) (Video Engine, Loudness & Dynamics, Channels & Stereo, Ambience & Space, EQ & Tone, Safety, Debug IPC) and read/mutate the providers via `Consumer`/`context.watch`.

### DSP audio pipeline (DspProvider)
- Every setter (`setEqBandGain`, `setCompThreshold`, `setBypass`, etc.) mutates `DspState` immutably via `copyWith`, rebuilds a preview string, and — if `autoApply` is on — debounces (120ms) a call to `_applyNow()`.
- [lib/services/filter_builder.dart](lib/services/filter_builder.dart) (`FilterBuilder`) turns `DspState` into a single FFmpeg `lavfi` filter-chain string (`dynaudnorm,pan,asplit/aecho ambience,extrastereo,anequalizer,highshelf,acompressor,alimiter`) and into the actual MPV IPC JSON command (`set_property af <chain>`).
- [lib/services/filter_parser.dart](lib/services/filter_parser.dart) (`FilterParser`) does the reverse: parses a raw filter string back into a `DspState` so the GUI sliders stay in sync when a custom/pasted filter string is loaded.
- Presets (`Preset` in [lib/models/preset.dart](lib/models/preset.dart)) bundle a `DspState` + optional raw `customFilter` override; user-saved ones persist through `PreferencesService`/`shared_preferences` as JSON.

### Video pipeline (VideoProvider)
- Unlike DSP, video properties are mostly set directly as individual MPV `set_property` commands (tone-mapping, target-peak, brightness/contrast/gamma, deband, tscale/scale/cscale/dscale, glsl-shaders), not built into one filter string.
- `applyPreset()` drip-feeds a whole batch of commands to MPV with 150ms gaps via `_sendCommandQueue` — this staggering is deliberate (MPV/ffmpeg can freeze if hit with a burst of IPC commands), so preserve it when adding new preset-driven properties instead of sending everything at once.
- Shader paths are resolved to absolute paths at `assets/shaders/` (or `data/flutter_assets/assets/shaders/` in release builds) before being sent, since MPV needs real filesystem paths, not Flutter asset keys.
- On startup, `_checkWindowsHdr()` calls the native platform channel to auto-default to full HDR passthrough if Windows HDR is currently enabled.

### MPV IPC transport (`MpvIpcService`)
- Desktop: connects via raw TCP socket to MPV (default `127.0.0.1:9001`); Web (`kIsWeb`): connects via a `WebSocketChannel` (default `ws://127.0.0.1:9002`). `dart:io` is behind a conditional import (`lib/stubs/io_stub.dart` stands in for `dart:io` on web builds), so any `dart:io` usage in shared code must go through the `io.` prefix import pattern already used in `mpv_ipc_service.dart`/`dsp_provider.dart`/`video_provider.dart`.
- `connect()` tries a list of candidate paths/ports in sequence, since MPV IPC can be reached either directly (raw TCP, desktop only) or through the Python/PowerShell WebSocket bridge.
- **The Python bridge ([mpv_websocket_bridge.py](mpv_websocket_bridge.py)) is required whenever the client is a WebSocket** (i.e., always on web, and on desktop whenever going through `ws://`) — it's a plain-socket WS server that proxies frames to MPV's TCP IPC socket. There's a PowerShell fallback ([mpv_websocket_bridge.ps1](mpv_websocket_bridge.ps1)) used if Python isn't available.
- `DspProvider.playTestVideo()` is the orchestrator for the one-click "launch & connect" flow: picks a video, launches `mpv.exe` with a per-session named-pipe IPC server (`--input-ipc-server=\\.\pipe\mpvsocket_<rand>`), unpacks and starts the bridge script (with a per-session random WebSocket port to avoid collisions), retries the WS connection up to 10 times, then applies the current DSP state immediately once connected.

### Windows native layer
- [windows/runner/flutter_window.cpp](windows/runner/flutter_window.cpp) registers a `MethodChannel` named `com.mpv_media_engine/platform` that Dart calls through [lib/services/platform_service.dart](lib/services/platform_service.dart). Currently it exposes one method, `isWindowsHdrEnabled`, implemented via DXGI (`IDXGIOutput6::GetDesc1`, checking for `DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020`). Linking against `dxgi.lib` is declared in [windows/runner/CMakeLists.txt](windows/runner/CMakeLists.txt).
- Any new native platform capability should be added as another `call.method_name()` branch in the same channel handler rather than creating a new channel.

## Notes on tests
The existing `test/` directory is minimal/exploratory (`preferences_test.dart` only mocks `SharedPreferences`, doesn't assert anything meaningful yet; `widget_test.dart` asserts the header text is `'MVP Sound Engine'`, which no longer matches the actual header text `'MPV Media Engine'` in `home_screen.dart` — that test currently fails). Don't assume test output reflects real regressions without checking.
