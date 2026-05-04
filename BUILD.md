# Build Guide — whisper_cpp GDExtension (Linux)

This guide covers building the `WhisperCpp` GDExtension on **Linux x86_64**.
For Windows, see [BUILD_WINDOWS.md](BUILD_WINDOWS.md).

## Prerequisites

| Tool | Notes |
|------|-------|
| Rust toolchain (stable) | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| cmake ≥ 3.16 | `apt install cmake` / `brew install cmake` |
| libclang / LLVM | Required by `bindgen` — see below |
| git | For cloning the whisper.cpp fork |

### Installing libclang

```bash
# Debian/Ubuntu
sudo apt install libclang-dev clang

# Homebrew (macOS or Linux)
brew install llvm
export LIBCLANG_PATH=$(brew --prefix llvm)/lib
```

If using a non-system LLVM installation:
```bash
export LIBCLANG_PATH=/path/to/llvm/lib
export PATH="$PATH:/path/to/llvm/bin"
```

---

## Clone the whisper.cpp Fork

```bash
git clone https://github.com/ClawfficeOrg/whisper.cpp
cd whisper.cpp
git checkout godot-whisper-cpp-node
```

---

## Build and Copy

```bash
# From the godot-extension directory:
cd whisper.cpp/godot-extension

# Set paths if needed (add to ~/.bashrc for persistence)
export LIBCLANG_PATH=/usr/lib/llvm-14/lib   # adjust to your LLVM version

# Build release
cargo build --release

# Copy to the Godot project
GODOT_PROJECT=/path/to/clawffice/careless-whisper-godot
mkdir -p "$GODOT_PROJECT/addons/whisper_cpp/bin"
cp target/release/libwhisper_cpp_gdext.so \
   "$GODOT_PROJECT/addons/whisper_cpp/bin/libwhisper_cpp_gdext.linux.release.x86_64.so"
```

Or use the included build script:

```bash
cd whisper.cpp/godot-extension
GODOT_PROJECT=/path/to/clawffice/careless-whisper-godot \
./build.sh --release
```

---

## API Changes Fixed (whisper-rs 0.16 + godot-rs 0.4)

The scaffold had a few API compatibility issues that were resolved:

1. `GString::from(String)` → `GString::from(string.as_str())` — godot-rs only accepts `&str`
2. `thread::spawn` with `Gd<T>` — `Gd<WhisperCpp>` is not `Send`; replaced with
   `Arc<Mutex<Option<Result>>>` polled in `_process()`
3. `full_n_segments()` returns `i32` directly (not `Result`)
4. `full_get_segment_text(i)` → `get_segment(i).to_str()` per whisper-rs 0.16 API

---

## Download a Model

```bash
mkdir -p models
wget -O models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
```

Other available models (see `scripts/autoload/model_manager.gd` for the full list):

| Model | Size | Notes |
|-------|------|-------|
| `ggml-tiny.en.bin` | 75 MB | Fastest, English-only |
| `ggml-base.en.bin` | 142 MB | Good balance (recommended) |
| `ggml-small.en.bin` | 466 MB | Better accuracy |
| `ggml-medium.en.bin` | 1.5 GB | High accuracy |

---

## Verify and Run

```bash
cd /path/to/clawffice/careless-whisper-godot
./run.sh
```

1. Click **⚙ Config**
2. Set model path to the `.bin` file downloaded above
3. Click **Load Model**
4. Hold **🎤 Hold to Record** and speak
5. Release → transcription appears

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| `LIBCLANG_PATH not set` | Export the variable pointing to the folder with `libclang.so` |
| `cmake not found` | Install cmake or add it to PATH |
| `cargo: command not found` | Install Rust via rustup |
| Linker error on Ubuntu | `sudo apt install build-essential` |
| `.so` not found at runtime | Verify the file was copied to `addons/whisper_cpp/bin/` |

---

## Build Environment (last confirmed working)

- Host: Linux x86_64
- Rust: 1.87+ stable
- LLVM/libclang: 14+ (Ubuntu) or via Homebrew
- cmake: 3.16+
- Godot: 4.6
