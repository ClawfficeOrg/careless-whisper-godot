# End-to-End Transcription Test Instructions

`scenes/test/transcription_e2e.tscn` is a headless-capable test scene that
exercises the full WhisperCpp transcription pipeline: model load → PCM ingest →
transcription signal. It exits with code **0** (pass) or **1** (fail).

## Quick-start

### Headless (CI / terminal)

```bash
# From the project root — quits after 60 s at the latest
godot --headless --quit-after 60 \
      --main-scene res://scenes/test/transcription_e2e.tscn
echo "Exit code: $?"
```

Or via the project runner:

```bash
./run.sh --headless --quit-after 60 \
         --main-scene res://scenes/test/transcription_e2e.tscn
```

### In-editor

1. Open `scenes/test/transcription_e2e.tscn` in the Godot editor.
2. Press **F5** (or *Debug → Run Current Scene*).
3. Watch the **Output** panel for `[E2E]` log lines ending in `PASS` or `FAIL`.

## Expected output

| Scenario | Exit code | Log lines |
|---|---|---|
| Extension not built | 0 | `[E2E] WhisperCpp GDExtension not loaded — skipping test (PASS)` |
| Extension loaded, no model downloaded | 0 | `[E2E] No model found in user://models — skipping test (PASS)` |
| Extension + model present | 0 | `[E2E] Transcription complete: "…" — PASS` |
| Extension loaded, transcription error | 1 | `[E2E] Transcription error: … — FAIL` |
| Timeout (> 30 s) | 1 | `[E2E] Timed out after 30 seconds — FAIL` |

## Prerequisites for a full (non-skip) run

1. **Build the WhisperCpp GDExtension** — see `BUILD.md` (Linux) or
   `BUILD_WINDOWS.md` (Windows) and copy the compiled `.so` / `.dll` to
   `addons/whisper_cpp/bin/`.
2. **Download a model** — launch the main app, open *Config*, and download at
   least one model (e.g. `tiny.en`). Models land in `user://models/`.
3. Re-run the test scene; it will load the first available local model and feed
   `assets/test_audio/short_en.wav` (1 s of silence at 16 kHz) through the
   extension. Because the audio is silence the transcription text may be empty
   — the test validates pipeline completion, not specific text content.

## Test audio

`assets/test_audio/short_en.wav` is a project-owned synthetic file: 1 second of
silence encoded as 16 kHz mono 16-bit PCM WAV. It satisfies the whisper.cpp
input requirements (16 kHz, mono, i16 LE) and has no copyright encumbrances.
Replace it with real speech to validate actual accuracy.
