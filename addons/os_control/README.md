# os_control addon — Input & Window Control

This addon exposes OS-level controls to Godot via a GDExtension. It provides:

- Window enumeration and control
- Input injection (keyboard/mouse)
- Platform helpers for macOS and Linux (partial)

## Testing Input Injection (Windows)

1. Build the os_control extension on Windows (MSVC):

```powershell
cd addons\os_control
cargo build --release --target x86_64-pc-windows-msvc
# Copy the DLL to the project bin
copy target\x86_64-pc-windows-msvc\release\careless_whisper_os.dll ..\..\addons\os_control\bin\windows\careless_whisper_os.dll -Force
```

2. Open the project in Godot on Windows and open the scene:
   `res://scenes/test/input_injector_test.tscn`

3. Click the buttons to exercise functions:
   - Type text: sends Unicode text via SendInput
   - Press Ctrl+C: simulates Ctrl+C key combo
   - Move mouse: moves cursor using SetCursorPos
   - Left click: simulates left mouse click

Notes:
- Input injection requires the project setting to allow simulated input. Check Project Settings > Input.
- SendInput may require the Godot window to have focus or for the target application to accept simulated input.
- Mapping of keys is basic; extend `map_key()` in `addons/os_control/src/input_injector.rs` for more keys.

If you encounter issues, paste Godot console logs here and I will iterate on mappings and flags.
