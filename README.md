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
- **Scaling & Motion Interpolation**: Tweak temporal scalers (`tscale`), Luma/Chroma upscalers (`ewa_lanczossharp`), and lock video sync to your display refresh rate for buttery smooth motion.
- **HDR to SDR Tone Mapping**: Instantly switch between tone mapping algorithms (bt.2446a, mobius, spline) and push target peak brightness for viewing dark HDR movies in bright rooms.
- **Hardware Grading & Deband**: Fix color banding on low-bitrate anime or adjust raw brightness/contrast sliders on the fly.
- **Video Presets**: One-click curated setups for Anime, Live Action, and HDR-to-SDR viewing environments.

### 🎧 Sound Engine (DSP)
- **Real-Time Parametric EQ**: A full 7-band EQ that updates instantly as you drag the sliders.
- **Dynamic Loudness Normalization (Night Mode)**: Built-in `DynAudNorm` processing to flatten aggressive cinematic dynamic ranges—hear whispered dialog clearly without getting deafened by explosions.
- **Audiophile Presets**: Target curves for popular headphones (Sony, Bose, Sennheiser) and speakers.
- **Spatial Up/Downmixing**: Manipulate the `pan` matrix to convert 5.1/7.1 surround sound to perfectly clear 2.0 stereo.

## 🚀 Getting Started

### Download & Run (Recommended)
1. Go to the [Releases page](https://github.com/ddinh99/MPV-Media-Engine/releases) and download the latest `MPV-Media-Engine-v1.2.zip`.
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
The application connects to MPV's JSON IPC (Inter-Process Communication) socket via an intermediate python bridge. As you interact with the UI, it translates your settings into raw MPV properties (like `glsl-shaders` or `tone-mapping`) and FFmpeg `lavfi` strings (like `af-add=lavfi=[...]`), sending them directly to the player to be processed on the fly.

## 💖 Support the Project
If this app helped you get the perfect picture and sound out of your home theater, consider buying me a coffee to support future updates!

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/daidinh)
