# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Fixed

- **`InputInjector` Windows `type_text` now works** — the compiled
  `careless_whisper_os.dll` was stale (built before the `SendInput` implementation
  was written). Rebuilt from source; `type_text`, `press_key`, `move_mouse`, and
  `click_mouse` all use the `windows` crate's `SendInput` / `SetCursorPos` APIs and
  are confirmed functional on Windows.

- **`scenes/main_scene.tscn` parse error fixed** — the scene file had three issues
  that caused Godot to fail with `Parse error` at line 5:
  1. `[gd_scene]` header was missing the required `load_steps` and `format=3`
     attributes.
  2. `ExtResource` was inlined as a raw path (`ExtResource(res://...)`) instead of
     being declared as a separate `[ext_resource ...]` block and referenced by id.
  3. The child node used `parent="Main"` (the root's own name) instead of the
     canonical `parent="."` (dot = scene root).

---

## [0.1.0] — 2025-06-10

### Added

- Godot 4.6 project scaffold with autoloads: `SignalBus`, `ConfigManager`,
  `ModelManager`, `CommandDispatcher`, `VimController`.
- Main UI scene (`scenes/main.tscn`): push-to-talk record button, transcription
  output, config dialog, loading overlay, mic level meter, vim mode toggle.
- `WhisperCpp` GDExtension wiring: non-blocking `load_model` / `transcribe` with
  signal-based results.
- `os_control` GDExtension (`addons/os_control/`): `WindowManager` (window
  enumeration) and `InputInjector` (keyboard + mouse injection) implemented for
  Windows via `SendInput` / `SetCursorPos`.
- Full Windows build instructions in `BUILD_WINDOWS.md`.
- Placeholder mode when neither extension is compiled — UI loads and is functional
  without the `.dll` files present.
- Audio pipeline: `AudioEffectCapture` → stereo-to-mono → linear-interpolation
  downsample to 16 kHz for whisper.cpp ingestion.
- `MicMeter` UI component (`scenes/ui/MicMeter.tscn`) with RMS level display.
- Input injector test scene (`scenes/test/input_injector_test.tscn`).
- GDScript linter script (`scripts/lint.sh`) with `--strict` mode.
