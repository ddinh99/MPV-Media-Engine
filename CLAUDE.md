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
- `applyPreset()` diffs the outgoing preset's `VideoState` against the currently-live one and only enqueues properties that actually changed — resending unchanged scale/shader/interpolation values forces needless libplacebo pipeline rebuilds. The **first** `applyPreset()` call after each new MPV (re)connection forces a full unconditional send regardless of the diff (`_needsFullResync`, reset via a `dspProvider` connection-state listener) — local `VideoState` is only ever a *guess* at MPV's live properties (a freshly connected MPV instance may already have shaders/scalers set from its own `mpv.conf` or a prior session), so the diff can't be trusted until we've done at least one confirmed full sync.
- Shader paths are resolved to absolute paths at `assets/shaders/` (or `data/flutter_assets/assets/shaders/` in release builds) before being sent, since MPV needs real filesystem paths, not Flutter asset keys.
- On startup, `_checkWindowsHdr()` calls the native platform channel to auto-default to full HDR passthrough if Windows HDR is currently enabled.
- **HDR Output** (`setHdrOutput`) is a GUI-only concept with no matching mpv property — it's a "force full HDR passthrough" shortcut that drives real properties underneath: `target-colorspace-hint=yes` + `target-trc=pq` + `inverse-tone-mapping=yes` when on, `target-trc=auto` + `inverse-tone-mapping=no` when off. It also gates two other controls: the **Visualizer** switch (`tone-mapping-visualize` draws nothing unless HDR Output is on, so it's disabled/force-off otherwise) and the separate **Target Hinting** switch (disabled while HDR Output is on, since HDR Output already owns `target-colorspace-hint`/`target-trc` and the two would otherwise fight over the same mpv state).

### MPV IPC transport
- **All outbound IPC commands funnel through one FIFO queue in `DspProvider`** (`sendRawCommand` → `_outbox` → `_drainOutbox()`), regardless of which provider/widget originated them. This is deliberate: MPV/libplacebo can freeze if hit with an unpaced burst of property changes, and having every call site independently manage its own `Timer`-based delay (the old approach) meant overlapping actions (e.g. switching presets while a slider drag was still debouncing) could interleave into a burst anyway. The queue enforces a minimum gap between *every* pair of consecutive sends (`_kMinCommandGap`, 150ms), with an optional longer `minGapAfter` for properties known to trigger a full render-pipeline rebuild (`scale`/`cscale`/`dscale`/`tscale`/`glsl-shaders`/`interpolation`/`video-sync` — see `VideoProvider._kExpensiveProperties`).
- `MpvIpcService` (Desktop): connects via raw TCP socket (default `127.0.0.1:9001`) or a `WebSocketChannel` (default `ws://127.0.0.1:9002`); Web (`kIsWeb`) always uses WebSocket. `dart:io` is behind a conditional import (`lib/stubs/io_stub.dart` stands in for `dart:io` on web builds), so any `dart:io` usage in shared code must go through the `io.` prefix import pattern already used in `mpv_ipc_service.dart`/`dsp_provider.dart`/`video_provider.dart`.
- **⚠️ mpv's `--input-ipc-server` on Windows is always a named pipe, never a raw TCP socket** — confirmed directly against mpv's own manual and by empirically launching mpv with `tcp://…` (it fails to bind, since mpv literally treats an unrecognized scheme as a literal pipe-name suffix). `MpvIpcService.connect()`'s `127.0.0.1:9001` TCP candidate and the "direct TCP" path only work if something *else* is proxying TCP↔pipe — they cannot connect to a real `mpv.exe` on Windows by themselves. The WebSocket bridge scripts exist for exactly this reason.
- **The bridge scripts ([mpv_websocket_bridge.py](mpv_websocket_bridge.py) / [mpv_websocket_bridge.ps1](mpv_websocket_bridge.ps1)) proxy MPV's named pipe ↔ a WebSocket** the app can actually connect to. `DspProvider.playTestVideo()` unpacks and launches one of them (Python tried first, PowerShell as fallback) with a per-session random WebSocket port and named pipe to avoid collisions, retries the WS connection up to 10 times, then applies the current DSP state immediately once connected. Neither bridge script currently relays MPV's own replies/events back to the app over the WebSocket direction — only app→MPV commands flow; this means the Command Log's `MPV: …` lines and anything depending on IPC responses/`observe_property` don't work over the WS path today, only over a genuine direct TCP connection (which, per above, isn't reachable on a real Windows mpv.exe either) or a manual named-pipe test client.

### Windows native layer
- [windows/runner/flutter_window.cpp](windows/runner/flutter_window.cpp) registers a `MethodChannel` named `com.mpv_media_engine/platform` that Dart calls through [lib/services/platform_service.dart](lib/services/platform_service.dart). Currently it exposes one method, `isWindowsHdrEnabled`, implemented via DXGI (`IDXGIOutput6::GetDesc1`, checking for `DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020`). Linking against `dxgi.lib` is declared in [windows/runner/CMakeLists.txt](windows/runner/CMakeLists.txt).
- Any new native platform capability should be added as another `call.method_name()` branch in the same channel handler rather than creating a new channel.

## Verified mpv property gotchas
Before adding/changing any mpv property name or value, cross-check it against a real mpv binary's `--list-options` (`mpv.exe --list-options`) rather than trusting memory or old snippets — several were wrong and shipped silently broken (mpv just returns an IPC error that the app ignores, so a wrong property name looks like "the slider does nothing" rather than a crash):
- `hdr-output` is **not a real mpv property** (confirmed: mpv errors "option not found" even at the CLI). There is no such thing — HDR passthrough is expressed via `target-colorspace-hint` + `target-trc` + `inverse-tone-mapping` instead (see `VideoProvider.setHdrOutput`).
- Contrast Recovery is `hdr-contrast-recovery` (range 0–2) — **not** `tone-mapping-contrast-recovery` or `contrast-recovery`, neither of which exist.
- `--tone-mapping` has no `none` value (`Invalid value` error); the real "disable" value is `clip`. The GUI keeps "None" as a friendly label but translates it via `_mpvToneMappingValue()` before sending.
- `tscale-window`'s value is `hanning`, not `hann`.
- `--tone-mapping` only actually inserts a mapping filter when the *loaded content's own* peak/gamut exceeds the configured `target-peak` (i.e. it's content-dependent, not something any GUI toggle alone determines) — see mpv's own manual wording under `--tone-mapping` and `--target-peak`.
- `--inverse-tone-mapping` must be explicitly enabled for mpv to expand dynamic range at all (SDR→HDR, or brightening HDR further); without it, the Algorithm dropdown does nothing in that direction regardless of which curve is selected.

## Notes on tests
The existing `test/` directory is minimal/exploratory (`preferences_test.dart` only mocks `SharedPreferences`, doesn't assert anything meaningful yet; `widget_test.dart` asserts the header text is `'MVP Sound Engine'`, which no longer matches the actual header text `'MPV Media Engine'` in `home_screen.dart` — that test currently fails). Don't assume test output reflects real regressions without checking.
