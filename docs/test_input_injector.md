# InputInjector Integration Test — Run Instructions

## Overview

`scenes/test/input_injector_integration.tscn` is a Godot scene that exercises
the **InputInjector** GDExtension class from `addons/os_control`.

It runs an automated self-test on startup and also provides manual buttons for
interactive verification.

---

## Prerequisites

### 1. Compile the `os_control` GDExtension

```bash
cd addons/os_control
cargo build --release
```

### 2. Copy the compiled binary

**Linux:**
```bash
cp target/release/libcareless_whisper_os.so \
   bin/release/libcareless_whisper_os.so
```

**Windows (from WSL or PowerShell):**
```powershell
copy target\release\careless_whisper_os.dll `
     bin\windows\careless_whisper_os.dll
```

**macOS:**
```bash
cp target/release/libcareless_whisper_os.dylib \
   bin/release/libcareless_whisper_os.dylib
```

> Binary paths must match those declared in
> `addons/os_control/os_control.gdextension`.

---

## Running the Test Scene

### In the Godot Editor

1. Open the project in Godot 4.6.
2. Navigate to `scenes/test/input_injector_integration.tscn`.
3. Press **F6** (or right-click → Run Scene).

### From the Command Line

```bash
godot --path /path/to/careless-whisper-godot \
      res://scenes/test/input_injector_integration.tscn
```

---

## Expected Behaviour

### With Extension Loaded

- **StatusLabel** shows `✓ InputInjector loaded — ready`.
- The automated test runs immediately and updates **ResultLabel** with
  individual pass/fail lines (✓ / ✗) and a summary count.
- All checks should show ✓ on a supported platform.
- On Linux the platform methods currently log via `godot_print` and return
  `true`; those checks will pass.

### Without Extension Loaded

- **StatusLabel** shows `⚠ InputInjector GDExtension not loaded — tests skipped`.
- All three buttons are disabled.
- No crash — the scene loads safely in placeholder mode.

---

## Manual Buttons

| Button | Action |
|--------|--------|
| **Run Auto-Test** | Re-runs the full automated check suite. |
| **Inject Key (Ctrl+A)** | Calls `press_key("ctrl+a")` and shows the return value. |
| **Inject Click (Left)** | Calls `click_mouse("left")` and shows the return value. |

---

## CI / Headless Notes

- The scene is **not** suitable for headless CI without the compiled extension
  because `InputInjector` makes real OS-level calls.
- In headless mode the extension will still be absent (no compiled `.so`/`.dll`
  in the `bin/` paths), so the scene gracefully skips all tests.
- The GDScript lint check (`./scripts/lint.sh --strict`) runs Godot headless
  for syntax validation only and does not execute `_ready` — it is safe to run
  without the extension compiled.
- If you add a CI job that executes the scene, ensure the runner has a compiled
  extension and a display server (or `--display-driver headless`); note that
  real input injection requires a graphical session on Linux (X11/Wayland).
