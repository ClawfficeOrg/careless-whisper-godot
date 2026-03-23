# Careless Whisper — Status Report

_Last updated: 2026-03-23_

## ✅ What's Working

### GDExtension
- **Loads successfully** in Godot 4.5.2 (`gdext_rust_init` entry point)
- **`WhisperCpp` class registers** — `ClassDB.class_exists("WhisperCpp")` returns `true`
- **Model loads** — `ggml-base.en.bin` (147MB) loads in ~1 second, no errors
- **API confirmed:** `load_model(path)`, `transcribe(bytes)`, `is_model_loaded()`, `is_transcribing()`
- **Signals confirmed:** `transcription_complete(text)`, `transcription_error(msg)`, `model_loaded(path)`

### Project Structure
- `scenes/main.tscn` — full UI scaffolded: record button, status label, output area, config dialog
- `scripts/ui/main.gd` — audio capture (AudioEffectCapture + AudioStreamMicrophone), signal wiring
- `scripts/ui/config_dialog.gd` — model picker with browse + load
- `scripts/autoload/signal_bus.gd` — decoupled signal routing
- `scripts/autoload/config_manager.gd` — persistent config (ConfigFile)
- `models/ggml-base.en.bin` — downloaded (142MB, ignored by git)
- `run.sh` — convenience launcher

### Audio Pipeline
Code is written and wired; uses `AudioEffectCapture` to grab mic frames, downsample stereo → mono i16 LE at 16kHz.

---

## ⚠️ What Needs Testing (Requires Display/Audio)

### 1. Audio Capture
- Does `AudioStreamMicrophone` work headlessly? (Likely not — needs a display + audio server)
- Is the sample rate actually 16kHz? Whisper needs exactly 16kHz mono. If the capture bus runs at a different rate (e.g. 44.1kHz), transcription will be wrong/garbled.
- **FIX NEEDED:** Add sample rate detection and resampling if necessary.

### 2. Full Transcription Flow
- Tested model load ✅
- Not yet tested: record → `transcribe(pcm_bytes)` → signal fires with text
- The transcription thread logic in Rust looks correct but untested end-to-end.

### 3. UI Rendering
- Scene was tested headless only — no visual test
- The `WhisperNode` is now correctly typed as `WhisperCpp` in the scene

---

## 🔧 Known Issues / TODOs

### Sample Rate (CRITICAL)
The `AudioEffectCapture` records at the **mix rate of the audio bus** (typically 44100 Hz or 48000 Hz).
Whisper.cpp expects **16000 Hz mono**. The current code doesn't resample.

**Quick fix:** Add downsampling in `_drain_audio_buffer()`:
```gdscript
# Check mix rate and resample to 16kHz
var mix_rate := AudioServer.get_mix_rate()  # e.g. 44100
var ratio := mix_rate / 16000.0
# Downsample: take every ratio-th sample
```

Or configure the audio bus to run at 16kHz (not recommended — affects all audio).

### Config Dialog
- Model path not pre-populated from saved config on first open — FIXED
- Need to test browse dialog in actual display mode

### Vim Integration (Future)
The transcription output goes to `OutputLabel`. For Vim control:
1. Route transcription to stdout or a FIFO
2. External script reads FIFO and sends keys to vim (`xdotool`, `xclip`, etc.)
3. Or use Godot's `OS.execute()` / `OS.shell_open()` to drive commands directly

---

## 🚀 How to Run

```bash
cd ~/workspace/git_repos/careless-whisper-godot-real

# First time: download model
curl -L -o models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin

# Launch
./run.sh
# or: godot --path . 
```

Then:
1. Click **⚙ Config**
2. Set model path to the absolute path of `models/ggml-base.en.bin`
3. Click **Load Model**
4. Hold the record button and speak
5. Release → transcription appears

---

## 📋 Next Steps (Priority Order)

1. **Fix sample rate** — detect + resample audio to 16kHz before sending to whisper
2. **Test full flow** with display/audio (Michael's machine)
3. **Command routing** — once transcription works, add basic command dispatch
4. **Vim integration prototype** — `xdotool type "..."` or clipboard → paste
