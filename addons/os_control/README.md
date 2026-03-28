# OS Control GDExtension

Cross-platform window management and input injection for careless-whisper.

## Features

- **WindowManager** - Get active window info, list all windows
- **InputInjector** - Type text, press keys, move/click mouse

## Supported Platforms

- ✅ Windows (Win32 API)
- ✅ macOS (Cocoa/CoreGraphics)
- ⚠️ Linux (X11 only - Wayland support limited)

## Building

### Prerequisites

- Rust toolchain (1.70+)
- Godot 4.6
- Platform-specific dev libraries

### Linux

```bash
sudo apt-get install libxcb1-dev libxcb-randr0-dev libxcb-ewmh-dev
```

### Build Steps

```bash
cd addons/os_control
cargo build --release
```

The shared library will be generated at:
- Windows: `target/release/careless_whisper_os.dll`
- macOS: `target/release/libcareless_whisper_os.dylib`
- Linux: `target/release/libcareless_whisper_os.so`

Copy to `bin/` directory:
```bash
mkdir -p bin/release
cp target/release/libcareless_whisper_os.* bin/release/
```

## Usage in GDScript

```gdscript
# Get active window info
var window_manager = WindowManager.new()
var active = window_manager.get_active_window()
print("Active window: ", active.title)
print("App: ", active.app_name)
print("Position: ", active.x, ", ", active.y)
print("Size: ", active.width, "x", active.height)

# List all windows
var windows = window_manager.list_windows()
for win in windows:
    print(win.title, " - ", win.app_name)

# Type text
var injector = InputInjector.new()
injector.type_text("Hello, World!")

# Press key combo
injector.press_key("ctrl+c")

# Move mouse
injector.move_mouse(100, 200)

# Click mouse
injector.click_mouse("left")
```

## Platform Limitations

### Linux (Wayland)
- Window enumeration requires compositor support
- KDE: Works via kdotool
- GNOME/Mutter: **No support** for external window enumeration
- Input injection may require accessibility permissions

### macOS
- Requires Accessibility permissions (System Preferences → Privacy)
- Screen Recording permission for window titles

### Windows
- No special permissions required
- Full support via Win32 API

## Implementation Status

| Feature | Windows | macOS | Linux |
|---------|---------|-------|-------|
| Get active window | ⚠️ Stub | ⚠️ Stub | ⚠️ Stub |
| List windows | ⚠️ Stub | ⚠️ Stub | ⚠️ Stub |
| Type text | ⚠️ Stub | ⚠️ Stub | ⚠️ Stub |
| Press keys | ⚠️ Stub | ⚠️ Stub | ⚠️ Stub |
| Move mouse | ⚠️ Stub | ⚠️ Stub | ⚠️ Stub |
| Click mouse | ⚠️ Stub | ⚠️ Stub | ⚠️ Stub |

⚠️ = Scaffolded, needs implementation

## Next Steps

1. Implement Windows input injection using SendInput
2. Implement macOS input injection using CGEvent
3. Implement Linux input injection using XTest
4. Add accessibility API integration for UI element detection
5. Add OCR fallback for apps without accessibility support

## References

- [active-win-pos-rs](https://github.com/dimusic/active-win-pos-rs)
- [godot-rust/gdext](https://github.com/godot-rust/gdext)
- [enigo](https://github.com/enigo-rs/enigo) - Cross-platform input simulation
