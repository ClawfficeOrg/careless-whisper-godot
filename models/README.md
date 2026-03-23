# Whisper Models

Place GGML whisper.cpp model files here. They are `.gitignore`d (large binary files).

## Download

```bash
# Base English model (~142MB) — good balance of speed/accuracy
curl -L -o models/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin

# Tiny English model (~77MB) — fastest, less accurate
curl -L -o models/ggml-tiny.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin

# Small English model (~488MB) — better accuracy
curl -L -o models/ggml-small.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin
```

## Usage

In the Godot app, open **Config** (⚙) and set the model path to the absolute path of the `.bin` file,
or use the **Browse…** button to find it.

The path will be saved and the model auto-loaded on next launch.

## Recommended for voice control

`ggml-base.en.bin` — fast enough for near-real-time on modern CPUs, good English accuracy.
