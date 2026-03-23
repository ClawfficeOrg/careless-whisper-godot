# Build Guide — whisper_cpp GDExtension

## Status

✅ **Successfully built** on 2026-03-23.

Output: `addons/whisper_cpp/bin/libwhisper_cpp_gdext.linux.release.x86_64.so` (4.3 MB)

## Prerequisites

| Tool | Required | How to get |
|------|----------|-----------|
| Rust toolchain | ✅ available | already installed (1.94.0) |
| cmake | ✅ available | via xpack bundled with qmd, or `brew install cmake` |
| libclang | ✅ available | `~/.homebrew/bin/brew install llvm` |

No root/sudo required — everything installs to `~/.homebrew`.

## Build Steps

```bash
# Set up paths (add to ~/.bashrc or run before each build)
export LIBCLANG_PATH=/home/node/.homebrew/Cellar/llvm/22.1.1/lib
export PATH="$PATH:/home/node/.homebrew/Cellar/llvm/22.1.1/bin"

# Build
cd ~/workspace/git_repos/whisper.cpp-clawffice/godot-extension
cargo build --release

# Copy to Godot project
GODOT_PROJECT=~/workspace/git_repos/careless-whisper-godot-real
mkdir -p "$GODOT_PROJECT/addons/whisper_cpp/bin"
cp target/release/libwhisper_cpp_gdext.so \
   "$GODOT_PROJECT/addons/whisper_cpp/bin/libwhisper_cpp_gdext.linux.release.x86_64.so"
```

Or use the build script:

```bash
cd ~/workspace/git_repos/whisper.cpp-clawffice/godot-extension
LIBCLANG_PATH=/home/node/.homebrew/Cellar/llvm/22.1.1/lib \
PATH="$PATH:/home/node/.homebrew/Cellar/llvm/22.1.1/bin" \
GODOT_PROJECT=~/workspace/git_repos/careless-whisper-godot-real \
./build.sh --release
```

## API Changes Fixed (whisper-rs 0.16 + godot-rs 0.4)

The scaffold had a few API compatibility issues that were fixed:

1. `GString::from(String)` → `GString::from(string.as_str())` — godot-rs only accepts `&str`
2. `thread::spawn` with `Gd<T>` — `Gd<WhisperCpp>` is not `Send`; replaced with `Arc<Mutex<Option<Result>>>` polled in `_process()`
3. `full_n_segments()` returns `i32` directly (not `Result`)
4. `full_get_segment_text(i)` → `get_segment(i).to_str()` per whisper-rs 0.16 API

## Next Steps

1. Download a model: `wget -O models/ggml-base.en.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin`
2. Open the Godot project and test with the main scene
3. The `.so` is gitignored — rebuild locally or add a CI artifact step

## Build Environment

- Host: openclaw-gateway (Linux x86_64)
- Rust: 1.94.0
- llvm/libclang: 22.1.1 (via Homebrew at `~/.homebrew`)
- cmake: 3.31.9 (via xpack in qmd node_modules)
