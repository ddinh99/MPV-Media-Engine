# MPV Sound Engine 🎛️

A real-time audio DSP and parametric EQ engine built specifically for the [MPV media player](https://mpv.io/).

Normally, adjusting audio filters (like dynamic range compression, downmixing, or EQ) in MPV requires writing complex, tedious FFmpeg `lavfi` chains in a text config file. **MPV Sound Engine** provides a beautiful, real-time GUI that injects these filters directly into your active MPV instance over WebSockets/IPC.

## ✨ Features

- **Real-Time Parametric EQ**: A full 7-band EQ that updates instantly as you drag the sliders. No need to restart your video.
- **Dynamic Loudness Normalization (Night Mode)**: Built-in `DynAudNorm` processing to flatten aggressive cinematic dynamic ranges—hear whispered dialog clearly without getting deafened by explosions.
- **Audiophile Presets**: One-click target curves for popular hardware, including:
  - **Headphones**: Audio-Technica ATH-M50x, Bose QC, Sony WH-1000XM, AirPods Pro, Sennheiser HD600.
  - **Speakers**: PreSonus Eris E3.5, JBL 305P, Edifier R1280T, Klipsch ProMedia 2.1, and more.
- **Spatial Up/Downmixing**: Manipulate the `pan` matrix to convert 5.1/7.1 surround sound to perfectly clear 2.0 stereo, or artificially widen the soundstage.
- **Custom Presets**: Save and load your own personal DSP filter chains.

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- Windows OS (Currently designed for Windows desktop).
- An active `mpv.exe` player.

### Installation & Running

1. Clone the repository:
   ```bash
   git clone https://github.com/ddinh99/MPV-Sound-Engine.git
   cd MPV-Sound-Engine
   ```
2. To launch the app safely and clean up any background processes, run the provided batch script:
   ```bash
   run_app.bat
   ```

## 🛠️ How it Works
The application connects to MPV's IPC (Inter-Process Communication) socket. As you interact with the UI, it translates your settings into raw FFmpeg `lavfi` strings (like `af-add=lavfi=[...]`) and sends them directly to the player to be processed on the fly.
