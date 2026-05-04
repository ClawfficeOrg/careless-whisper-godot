# Careless Whisper — Status Report

_Last updated: 2025-06-10_

## ✅ What's Working

### Project & Build

- **Godot 4.6** project — `project.godot` has `config/features=PackedStringArray("4.6")`
- **GDScript** — all `.gd` files audited and updated for Godot 4.6 compatibility
  (type annotations, `@onready` correctness, safe ClassDB extension instantiation)
- **`run.sh`** — convenience launcher working
- Placeholder mode active when extensions are not compiled — UI loads and functions

### GDExtension (whisper_cpp)

- Extension source lives in sibling repo: `whisper.cpp/godot-extension/` (branch `godot-whisper-cpp-node`)
- `whisper_cpp.gdextension` — `compatibility_minimum = "4.3"`, confirmed compatible with 4.6
- Multi-platform library paths declared for Linux, Windows, macOS
- **`WhisperCpp` class API confirmed:**
  - `load_model(path: String) -> bool` — non-blocking, emits `model_loaded` or `transcription_error`
  - `transcribe(bytes: PackedByteArray)` — non-blocking, emits `transcription_complete`
  - `is_model_loaded() -> bool`
  - `is_transcribing() -> bool`
  - `language: String`, `threads: int`

### GDExtension (os_control)

- Source in `addons/os_control/` (Rust, godot-rs 0.4)
- `os_control.gdextension` — `compatibility_minimum = "4.1"`, confirmed compatible with 4.6
- Provides `WindowManager` (window enumeration) and `InputInjector` (keyboard/mouse)
- Cross-platform: Windows (`windows` crate), macOS (`cocoa`/`core-graphics`), Linux (`xcb`)

### Project Structure

- `scenes/main.tscn` — full UI: record button, status label, output area, config dialog,
  loading overlay, mic level meter, vim mode toggle
- `scripts/ui/main.gd` — audio capture (AudioEffectCapture + AudioStreamMicrophone),
  linear-interpolation resampling to 16kHz, signal wiring
- `scripts/ui/config_dialog.gd` — model picker with browse, load, language/threads config
- `scripts/ui/model_browser.gd` — model download/delete/load UI with progress bar
- `scripts/ui/MicMeter.gd` — passive RMS level display via SignalBus
- `scripts/ui/loading_overlay.gd` — animated spinner overlay during model loads
- `scripts/autoload/signal_bus.gd` — decoupled signal routing
- `scripts/autoload/config_manager.gd` — persistent config (ConfigFile, user://config.cfg)
- `scripts/autoload/model_manager.gd` — model download/discovery (HTTPRequest, user://models/)
- `scripts/autoload/command_dispatcher.gd` — voice command parsing via RegEx
- `scripts/integrations/vim_controller.gd` — vim mode via xdotool or native InputInjector

### Audio Pipeline

- `AudioEffectCapture` captures mic frames into ring buffer
- Stereo → mono, linear-interpolation downsampling to 16kHz (from 44100/48000 Hz bus rate)
- RMS level emitted via `SignalBus.audio_level` for the mic meter

---

## ⚠️ What Needs Testing (Requires Display/Audio Hardware)

### 1. Full Transcription Flow
- Model load tested (non-blocking, emits signal) ✅
- Not yet tested end-to-end: record → `transcribe(pcm_bytes)` → signal fires with text

### 2. Audio Capture
- Does `AudioStreamMicrophone` enumerate correctly on target hardware?
- Verify the downsampled 16kHz PCM is accepted by whisper.cpp without artifacts

### 3. UI Rendering
- Scene tested in placeholder mode only — no visual test with GDExtension loaded
- Config dialog tab layout (Settings + Models tabs)

### 4. Model Downloads
- `ModelManager.download_model()` uses `HTTPRequest` with `use_threads = true`
- Progress monitoring via `Tween` — needs network + display to verify

---

## 🔧 Known Issues / TODOs

### GDExtension: os_control Not in Autoloads

`OSController` (`scripts/autoload/os_controller.gd`) is defined but **not listed as
an autoload** in `project.godot`. It uses `ClassDB.instantiate()` for `WindowManager`
and `InputInjector`, but the autoload wiring is absent. This means window-change
signals won't fire until it's added to the project autoloads.

**Fix needed:** Add to `project.godot` autoloads section:
```
OSController="*res://scripts/autoload/os_controller.gd"
```

### InputInjector Test Scene

`scenes/test/input_injector_test.tscn` references `InputInjector.new()` in the old
test script. The script has been fixed to use `ClassDB.instantiate()`, but the scene
may need a re-import in the editor.

### Config Dialog

- Model path pre-populated from saved config ✅ (fixed)
- Browse dialog needs real display to test FileDialog behavior

### Vim Integration (xdotool fallback)

`xdotool` is Linux/X11 only. On Wayland or Windows, the `InputInjector` native path
via `os_control` extension is required. Test on each platform.

---

## 🚀 How to Run

```bash
cd /path/to/clawffice/careless-whisper-godot

# First time: download model
curl -L -o models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin

# Launch
./run.sh
# or: godot --path .
```

Then:
1. Click **⚙ Config**
2. In the **Settings** tab, set model path to the `.bin` file above
3. Click **Load Model**
4. Hold **🎤 Hold to Record** and speak
5. Release → transcription appears in the output area

---

## 📋 Next Steps (Priority Order)

1. **Test full transcription flow** on a machine with display + audio
2. **Add OSController to autoloads** in `project.godot`
3. **Verify resampling quality** — confirm 16kHz PCM produces clean transcriptions
4. **Command routing** — once transcription works, exercise `CommandDispatcher` patterns
5. **Vim integration** — test `xdotool` path on Linux/X11 and native path on Windows
6. **Build whisper_cpp for Windows** — follow `BUILD_WINDOWS.md`
7. **CI artifact** — add GitHub Actions workflow to build and cache the `.so`/`.dll`
