# Careless Whisper

Cross-platform desktop speech recognition — Godot 4.6 + whisper.cpp GDExtension.

## Architecture

```
careless-whisper-godot/          ← this repo  (Godot project)
└── addons/whisper_cpp/          ← GDExtension files + compiled .so/.dll
    ├── whisper_cpp.gdextension
    └── bin/                     ← compiled shared libraries go here

ClawfficeOrg/whisper.cpp         ← whisper.cpp fork
└── godot-extension/             ← Rust GDExtension source
    ├── Cargo.toml
    ├── build.sh                 ← build + copy to Godot project
    └── src/
        ├── lib.rs
        └── whisper_node.rs      ← WhisperCpp GDExtension class
```

## Quick Start

### 1. Build the GDExtension

**Requirements:** Rust toolchain, cmake, libclang

```bash
# Clone the whisper.cpp fork and check out the extension branch
git clone https://github.com/ClawfficeOrg/whisper.cpp
cd whisper.cpp
git checkout godot-whisper-cpp-node

# Build and copy into your Godot project
cd godot-extension
GODOT_PROJECT=/path/to/careless-whisper-godot ./build.sh
```

### 2. Download a Model

```bash
cd /path/to/careless-whisper-godot
mkdir -p models
wget -O models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
```

### 3. Open in Godot 4.6

1. Open `careless-whisper-godot` as a Godot project
2. Run the project
3. Click **⚙ Config** → set model path → **Load Model**
4. Hold the **🎤 Hold to Record** button and speak
5. Release → transcription appears

## API (GDScript)

```gdscript
# Get the WhisperCpp node
@onready var whisper: Node = $WhisperNode

# Load a model (synchronous, may be slow for large models)
whisper.load_model("/path/to/ggml-base.en.bin")

# Transcribe raw PCM (mono, 16 kHz, i16 LE bytes)
whisper.transcription_complete.connect(func(text): print(text))
whisper.transcribe(my_pcm_bytes)

# Check state
whisper.is_model_loaded()   # → bool
whisper.is_transcribing()   # → bool
whisper.language            # → String  (e.g. "en")
whisper.threads             # → int
```

## Signals

| Signal | Args | Description |
|--------|------|-------------|
| `transcription_complete` | `text: String` | Transcription finished |
| `transcription_error` | `msg: String` | Error during transcription |
| `model_loaded` | `path: String` | Model loaded successfully |

## Development

See [SPEC.md](SPEC.md) for the full technical specification and phase roadmap.

### Phase 1 status

- [x] GDExtension Rust scaffold (`godot-extension/`)
- [x] `WhisperCpp` class — `load_model`, `transcribe`, signals
- [x] Background thread inference with `call_deferred` dispatch
- [x] Godot project structure — autoloads, scenes, scripts
- [x] Main UI — record button (push-to-talk), transcription output
- [x] Config dialog — model picker, language, threads
- [x] Placeholder mode when extension not built
- [ ] Built shared library (requires cmake + libclang on build host)
