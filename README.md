# MPV Media Engine 🎛️🎬

![Screenshot 1](screenshots/MPVME1.jpg)
![Screenshot 2](screenshots/MPVSE1.jpg)
![Screenshot 3](screenshots/MPVSE2.jpg)
![Screenshot 4](screenshots/MPVSE3.jpg)
![Screenshot 5](screenshots/MPVSE4.jpg)

A real-time master control surface built specifically for the [MPV media player](https://mpv.io/). 

Normally, adjusting video shaders, scalers, or complex audio DSP filters (like dynamic range compression and EQ) in MPV requires writing complex, tedious commands in a text config file. **MPV Media Engine** provides a beautiful, real-time GUI that injects these changes directly into your active MPV instance over WebSockets/IPC without ever having to restart your video.

## ✨ Features

### 🎬 Video Engine
- **Custom Shader Injection**: Dynamically inject, toggle, and reorder GLSL shaders (like `Anime4K`, `FSRCNNX`, `CAS`) in real-time.
- **Resolution-Aware Shader Recommendations**: The Shaders tab reads your video's live resolution, groups shaders into Low-Res/High-Res tiers, and lists them in a sensible enable order (upscale → refine → chroma → sharpen) so you can just check boxes top-to-bottom and get a solid default chain.
- **High Performance Mode**: Native temporal motion interpolation targeting high-refresh-rate displays. Fine-tune your `tscale` kernel (Box, Spline64, Mitchell) and windowing functions (Sphinx, Hann) for buttery smooth, ghost-free panning.
- **HDR to SDR Tone Mapping**: Instantly switch between tone mapping algorithms (bt.2446a, mobius, spline) and push target peak brightness for viewing dark HDR movies in bright rooms.
- **Automatic Windows HDR Detection**: On startup, the app checks if Windows HDR is currently enabled and auto-defaults to full HDR passthrough — no manual setup needed.
- **SDR to HDR Expansion**: Manually force `target-colorspace-hint` and dynamically target specific Primaries, Gamuts, and TRCs (like `bt.2020` or `pq`) to perfectly map content to your high-end HDR monitor.
- **Hardware Grading & Deband**: Fix color banding on low-bitrate anime or adjust raw brightness/contrast sliders on the fly.
- **Smart & Custom Presets**: One-click curated setups for Anime, Live Action, and HDR. You can also save and load your own tailored **Custom Video Presets**. Includes a handy "Bypass (Default)" panic button to instantly reset the engine if you push settings too far.

### 🎧 Sound Engine (DSP)
- **Real-Time Parametric EQ**: A full 7-band EQ that updates instantly as you drag the sliders.
- **Dynamic Loudness Normalization (Night Mode)**: Built-in `DynAudNorm` processing to flatten aggressive cinematic dynamic ranges—hear whispered dialog clearly without getting deafened by explosions.
- **Audiophile Presets**: Target curves for popular headphones and speakers (Sony, Bose, Sennheiser, Klipsch) plus dedicated gaming-headset and TV/soundbar presets.
- **Spatial Up/Downmixing**: Manipulate the `pan` matrix to convert 5.1/7.1 surround sound to perfectly clear 2.0 stereo.

### ⚙️ Quality of Life
- **Persistent Sessions**: The app remembers your last-used sound and video settings across launches, so you don't have to reapply your setup every time.
- **In-App Update Checker**: A dismissible banner lets you know right in the app when a new release is available on GitHub.
- **Themes**: Choose between Dark, Teal, and Light interface themes.
- **Resilient IPC Connection**: Every command is funneled through a single paced queue to prevent mpv/libplacebo from freezing under a burst of changes, with automatic full-state resync if mpv reconnects mid-session.
- **Debug IPC Console**: A dedicated tab shows the raw JSON IPC traffic to and from mpv, for troubleshooting connection issues.

## 🚀 Getting Started

### Download & Run (Recommended)
1. Go to the [**latest release**](https://github.com/ddinh99/MPV-Media-Engine/releases/latest) and download the zip attached there.
2. Extract the folder and double-click `MPV_Media_Engine.exe` to launch the GUI.
*(Note: You do **not** need Flutter or any programming tools installed to run the pre-compiled application!)*

### Building from Source (For Developers)
#### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- Windows OS (Currently designed for Windows desktop).
- An active `mpv.exe` player.

1. Clone the repository:
   ```bash
   git clone https://github.com/ddinh99/MPV-Media-Engine.git
   cd MPV-Media-Engine
   ```
2. To launch the app safely and clean up any background processes, run the provided batch script:
   ```bash
   run_app.bat
   ```

## 🛠️ How it Works
The application connects to MPV's JSON IPC (Inter-Process Communication) named pipe via an intermediate PowerShell bridge — no Python or other runtime needed, since `powershell.exe` ships with Windows. As you interact with the UI, it translates your settings into raw MPV properties (like `glsl-shaders` or `tone-mapping`) and FFmpeg `lavfi` strings (like `af-add=lavfi=[...]`), sending them directly to the player to be processed on the fly.

## 💖 Support the Project
If this app helped you get the perfect picture and sound out of your home theater, consider buying me a coffee to support future updates!

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/daidinh)
