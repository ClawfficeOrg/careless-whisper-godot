# careless-whisper OS Control Research
**Date:** 2026-03-27
**Purpose:** Research OS-level control capabilities for vim-like voice commands across applications

---

## Executive Summary

For careless-whisper (Godot 4.6 + whisper.cpp) to provide cross-platform voice control, we need:

1. **Window Enumeration** - Rust via GDExtension (godot-rust/gdext)
2. **UI Element Detection** - Platform-specific accessibility APIs
3. **Overlay Windows** - Platform-specific approaches (winit + layer-shell)
4. **App-Specific Integration** - CDP for browsers, scripting APIs for major apps

**Recommended approach:** Build a Rust GDExtension library that wraps platform-specific APIs and exposes them to Godot via GDScript.

## Vim-like text entry - push-to-talk buttons for insert mode, visual mode, command mode
- insert mode is standard text entry (maybe one push to talk button for keyboard typing emulation and one for just inserting text all at once)
- visual mode is for selection, cursor management, but unlike vim also responds to commands like replace with<words> or surround with <character>. Support for multicursor will have to be emulated in most places, command will be something like "replace all instances of <string> with <string>" and they will each be serially replaced instead of all at once like multi cursor.
- command mode is for ui control stuff like "switch to <application>" or "select window <window name>" or "execute <application specific command>". first commands to build are universal: copy, paste, cut, close, 
- BYOK AI support for openai compatible, anthropic compatible, local compatible (lm studio, ollama, etc starting with lm studio and openai compatible local models)
- MCP commands
- helper overlay that gives contextual recommendations of commands like neovim's whichkey
- support for application commands can come from multiple sources
  - mcp server?
  - menu commands
  - keyboard shortcuts
  - ui elements like buttons
  - streamdeck mcp
- support for 
- kb shortcut or command to bring up vimum-like Vomnibar (Whisbar)
- vim-like scrolling for all apps when in command mode
- default keyboard shortcut for commandmode on windows is win-capslock, PTT is just holding caps lock
- running select window command without specifying name will bring up overlay with window names and a shortcut with a few letters assigned to each
- same with any ambiguous "select <something>" command
- 
---

## 1. Window Enumeration

### Platform-Specific APIs

#### Windows (Win32)
```cpp
// Core APIs
EnumWindows() - enumerate all top-level windows
GetForegroundWindow() - get active window
GetWindowText() - window title
GetWindowRect() - position/size
GetWindowThreadProcessId() - process info
```

**Key structures:**
- `HWND` - window handle
- `RECT` - bounding rectangle
- `WINDOWINFO` - extended window info

#### macOS (Cocoa/AppKit)
```swift
// Core APIs
CGWindowListCopyWindowInfo() - list all windows
AXUIElementCopyAttributeValue() - accessibility attributes
NSWorkspace.shared.frontmostApplication - active app
```

**Key functions:**
- `AXUIElementCreateApplication(pid)` - get app accessibility root
- `AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute, ...)` - get windows
- `kAXPositionAttribute`, `kAXSizeAttribute`, `kAXTitleAttribute` - properties

**Permission required:** Screen Recording permission (System Preferences → Privacy)

#### Linux (X11 + Wayland)

**X11/XCB:**
```c
XQueryTree() - enumerate windows
XGetInputFocus() - focused window
XGetWindowProperty() with _NET_ACTIVE_WINDOW - active window (EWMH)
XFetchName() - window title
```

**Wayland:**
- **No universal API** - compositor-specific
- KDE: `kdotool` CLI tool
- GNOME/Mutter: **No support** for external window enumeration
- Layer-shell protocol for overlays only

### Cross-Platform Rust Library

**Recommended:** [active-win-pos-rs](https://github.com/dimusic/active-win-pos-rs)

```rust
use active_win_pos_rs::get_active_window;

fn main() {
    match get_active_window() {
        Ok(active_window) => {
            println!("title: {}", active_window.title);
            println!("position: {:?}", active_window.position);
            println!("process_id: {}", active_window.process_id);
        }
        Err(()) => println!("error getting active window")
    }
}
```

**Features:**
- Windows: Win32 API
- macOS: Cocoa/CoreGraphics
- Linux: XCB + Wayland (KDE via kdotool)
- Returns: `ActiveWindow { title, process_path, app_name, window_id, process_id, position }`

**Linux dependencies:**
```bash
sudo apt-get install libxcb-ewmh-dev libxcb-randr0-dev libdbus-1-dev pkg-config
```

### Godot Integration (GDExtension)

Use [godot-rust/gdext](https://github.com/godot-rust/gdext) for Godot 4:

```rust
use godot::prelude::*;

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
struct WindowManager {
    base: Base<RefCounted>,
}

#[godot_api]
impl WindowManager {
    #[func]
    fn get_active_window(&self) -> Dictionary {
        let mut dict = Dictionary::new();
        match active_win_pos_rs::get_active_window() {
            Ok(win) => {
                dict.set("title", win.title.to_godot());
                dict.set("app_name", win.app_name.to_godot());
                dict.set("x", win.position.x);
                dict.set("y", win.position.y);
                dict.set("width", win.position.width);
                dict.set("height", win.position.height);
            }
            Err(_) => {
                dict.set("error", "Failed to get active window".to_godot());
            }
        }
        dict
    }
}
```

---

## 2. UI Element Detection

### Windows (UI Automation)

**API:** Microsoft UI Automation (UIA)
**Header:** `uiautomation.h` (Windows SDK)

```cpp
#include <uiautomation.h>

IUIAutomation* pAutomation;
IUIAutomationElement* pRoot;
IUIAutomationElement* pFocused;

// Initialize
CoCreateInstance(__uuidof(CUIAutomation), NULL, CLSCTX_INPROC_SERVER,
                 __uuidof(IUIAutomation), (void**)&pAutomation);

// Get focused element
pAutomation->GetFocusedElement(&pFocused);

// Get properties
VARIANT varName;
pFocused->GetCurrentPropertyValue(UIA_NamePropertyId, &varVar);

// Get all children
IUIAutomationElementArray* pChildren;
pFocused->FindAll(TreeScope_Children, condition, &pChildren);
```

**Key property IDs:**
- `UIA_NamePropertyId` - element name
- `UIA_ControlTypePropertyId` - type (button, edit, etc.)
- `UIA_BoundingRectanglePropertyId` - screen coords
- `UIA_IsEnabledPropertyId`, `UIA_IsKeyboardFocusablePropertyId`

**Control Patterns:**
- `InvokePattern` - clickable elements
- `ValuePattern` - text fields
- `TogglePattern` - checkboxes
- `SelectionPattern` - lists

### macOS (Accessibility API)

```swift
import ApplicationServices

// Get accessibility element for app
let appRef = AXUIElementCreateApplication(pid)

// Get windows
var value: AnyObject?
AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
let windows = value as! [AXUIElement]

// For each window, enumerate children
for window in windows {
    var children: AnyObject?
    AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &children)
    
    // Get properties
    var title: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
    
    var position: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
    
    var role: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
}
```

**Common roles:**
- `kAXButtonRole`, `kAXCheckBoxRole`, `kAXTextFieldRole`
- `kAXTextAreaRole`, `kAXListRole`, `kAXMenuBarRole`
- `kAXMenuItemRole`, `kAXWindowRole`

**Permissions:**
- System Preferences → Privacy & Security → Accessibility
- Screen Recording permission for window titles

### Linux (AT-SPI2)

**API:** AT-SPI2 (D-Bus based)
**Python bindings:** `pyatspi2`

```python
import pyatspi

# Get desktop
desktop = pyatspi.Registry.getDesktop(0)

# Enumerate apps
for app in desktop:
    print(f"App: {app.name}")
    
    # Enumerate windows/frames
    for window in app:
        print(f"  Window: {window.name}")
        
        # Enumerate widgets
        for widget in window:
            role = widget.getRole()
            name = widget.name
            text = widget.queryText() if widget.queryText() else None
```

**D-Bus interface:**
```
org.a11y.Bus - accessibility bus
org.a11y.atspi.Registry - app registry
org.a11y.atspi.Accessible - element interface
```

**Install:**
```bash
sudo apt-get install python3-pyatspi at-spi2-core
```

### OCR Fallback

For apps without accessibility support:

**Rust:** `tesseract-rs` or `leptonica-sys`
**Python:** `pytesseract`, `easyocr`

```rust
use tesseract::Tesseract;

fn ocr_region(x: i32, y: i32, width: i32, height: i32) -> String {
    // Capture screen region (platform-specific)
    let image = capture_screen_region(x, y, width, height);
    
    // OCR
    let mut tess = Tesseract::new(None, Some("eng")).unwrap();
    tess.set_image(&image);
    tess.get_text()
}
```

**Recommended approach:** Use accessibility APIs first, OCR only as fallback.

---

## 3. Application Control Overlays

### Windows

**Win32 styles for overlay:**
```rust
use winapi::um::winuser::*;

// Create overlay window
let hwnd = CreateWindowExW(
    WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW,
    // ... window class, title, etc.
);

// Set transparency
SetLayeredWindowAttributes(hwnd, 0, 200, LWA_ALPHA); // 200 = 78% opacity

// Click-through
// WS_EX_TRANSPARENT makes window click-through
// But you can still draw on it
```

**winit approach:**
```rust
use winit::window::{WindowBuilder, WindowLevel};

let window = WindowBuilder::new()
    .with_decorations(false)
    .with_transparent(true)
    .with_window_level(WindowLevel::AlwaysOnTop)
    .build(&event_loop)?;

window.set_cursor_hittest(false)?; // Click-through
```

### macOS

**NSPanel for overlay:**
```swift
import AppKit

let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)

panel.level = .floating
panel.isFloatingPanel = true
panel.hidesOnDeactivate = false
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.ignoresMouseEvents = true // Click-through
```

**Permission:** None required for basic overlay, but need Accessibility for interaction.

### Linux (X11)

```c
Display* disp = XOpenDisplay(NULL);
Window root = DefaultRootWindow(disp);

// Create overlay window
Window overlay = XCreateSimpleWindow(disp, root, 0, 0, width, height, 0, 0, 0);

// Set properties for always-on-top, transparent
Atom wm_state = XInternAtom(disp, "_NET_WM_STATE", False);
Atom state_above = XInternAtom(disp, "_NET_WM_STATE_ABOVE", False);
XChangeProperty(disp, overlay, wm_state, XA_ATOM, 32, PropModeReplace,
                (unsigned char*)&state_above, 1);

// Set window type to dock/overlay
Atom wm_type = XInternAtom(disp, "_NET_WM_WINDOW_TYPE", False);
Atom type_dock = XInternAtom(disp, "_NET_WM_WINDOW_TYPE_DOCK", False);
XChangeProperty(disp, overlay, wm_type, XA_ATOM, 32, PropModeReplace,
                (unsigned char*)&type_dock, 1);
```

### Linux (Wayland)

**Layer Shell Protocol** (wlr-layer-shell or gtk4-layer-shell):

```rust
// Using gtk4-layer-shell
use gtk4_layer_shell::{Layer, LayerShell};

let window = gtk::ApplicationWindow::new(&app);
window.init_layer_shell();
window.set_layer(Layer::Overlay);
window.set_keyboard_mode(KeyboardMode::None); // Don't grab keyboard
```

**Protocol:** `wlr-layer-shell-unstable-v1`
- Layers: Background, Bottom, Top, Overlay
- Overlay is above all app windows
- Keyboard mode: None (pass-through) or Exclusive (grab)

**Compatibility:**
- KDE: Full support
- GNOME: **No layer-shell support** (as of 2026)
- Sway, Hyprland, wlroots compositors: Full support

**Reference:** [koverlay](https://github.com/erik96/koverlay) - click-through overlay for Wayland

---

## 4. App-Specific Command Integration

### Browsers (Chrome/Firefox)

**Chrome DevTools Protocol (CDP):**

```javascript
// Connect to Chrome with remote debugging
// chrome --remote-debugging-port=9222

const CDP = require('chrome-remote-interface');

async function main() {
    const client = await CDP();
    const {Page, Runtime, DOM} = client;
    
    await Page.enable();
    await DOM.enable();
    
    // Get all tabs
    const targets = await CDP.List();
    
    // Execute script in page
    const result = await Runtime.evaluate({
        expression: 'document.title'
    });
    
    // Navigate
    await Page.navigate({url: 'https://example.com'});
    
    // Click element
    const doc = await DOM.getDocument();
    const node = await DOM.querySelector({
        nodeId: doc.root.nodeId,
        selector: '#my-button'
    });
    await DOM.resolveNode({nodeId: node.nodeId});
}
```

**Key CDP domains:**
- `Page` - navigation, lifecycle
- `Runtime` - JavaScript execution
- `DOM` - DOM queries, events
- `Input` - synthetic mouse/keyboard
- `Emulation` - viewport, device mode

**Setup:** Launch Chrome with `--remote-debugging-port=9222`

### VSCode

**Extension API (from within VSCode):**
```typescript
import * as vscode from 'vscode';

// Execute any VSCode command
vscode.commands.executeCommand('workbench.action.files.save');
vscode.commands.executeCommand('editor.action.formatDocument');
vscode.commands.executeCommand('workbench.action.quickOpen');

// Get available commands
const commands = await vscode.commands.getCommands();
```

**External control:** Use `code` CLI or DAP (Debug Adapter Protocol)

### Adobe Creative Suite

**Photoshop UXP (JavaScript):**
```javascript
// UXP plugin API
const { app, core } = require("photoshop");

// Execute Photoshop actions
await core.executeAsModal(async () => {
    const doc = app.activeDocument;
    const layer = doc.activeLayer;
    
    // Apply filters, adjustments, etc.
    await layer.adjustBrightness(50);
});
```

**Scripting reference:** Adobe ExtendScript/UXP

### Blender

**Python API:**
```python
import bpy

# Execute operators
bpy.ops.object.select_all(action='SELECT')
bpy.ops.transform.translate(value=(1, 0, 0))

# Access data
obj = bpy.context.active_object
obj.location = (0, 0, 5)
```

### Godot

**GDScript:**
```gdscript
# Call any engine method
get_tree().quit()
EditorInterface.open_scene_from_path("res://main.tscn")
```

**External control:** Godot has no external API. Use:
- Accessibility APIs (as fallback)
- Custom IPC (TCP/UDP socket in Godot)

---

## 5. Existing Projects to Study

### Talon Voice

**GitHub:** https://github.com/talonvoice

**Architecture:**
- Windows: UI Automation + Win32
- macOS: Accessibility API (AXUIElement)
- Linux: X11 only (Wayland not supported)
- Voice: Custom engine + Dragon NaturallySpeaking

**Key learnings:**
- Accessibility API is primary mechanism
- OCR as fallback for unsupported apps
- Community grammars for app-specific commands

**Limitation:** No Wayland support planned (APIs don't exist)

### Hammerspoon (macOS)

**Website:** https://www.hammerspoon.org

**Architecture:**
- Lua scripting
- macOS Accessibility + CGEvent for input
- Window management, hotkeys, app automation

**Key API:**
```lua
hs.window.filter.default:getWindows()
hs.window.focusedWindow():moveToUnit(hs.layout.left50)
hs.eventtap.keyStroke({"cmd"}, "c")
```

### AutoHotkey (Windows)

**Architecture:**
- Custom scripting language
- Win32 API wrapper
- Hotkeys, window management, automation

**Key patterns:**
```autohotkey
WinGetTitle, title, A  ; Get active window title
WinMove, title,, 0, 0, 800, 600
Send, ^c  ; Ctrl+C
```

### Vimperator / Surfingkeys

**Architecture:**
- Browser extensions
- DOM manipulation + keyboard events
- Hint mode for link selection

**Key features:**
- `f` - show link hints
- `h/j/k/l` - scroll
- `:open URL` - command mode
- Custom keybindings in JS config

---

## 6. Recommended Implementation Path

### Phase 1: Core Window Management (2-3 weeks)

1. **Create Rust GDExtension**
   - Use `godot-rust/gdext` for Godot 4
   - Wrap `active-win-pos-rs` for window enumeration
   - Expose to GDScript

2. **Implement basic commands:**
   - "window title" - announce active window
   - "switch to [app]" - focus app by name
   - "list windows" - enumerate all windows

### Phase 2: Accessibility Integration (4-6 weeks)

3. **Platform accessibility wrappers:**
   - Windows: UI Automation (COM)
   - macOS: AXUIElement (C API)
   - Linux: AT-SPI2 (D-Bus)

4. **Implement UI element commands:**
   - "click button [name]"
   - "focus field [name]"
   - "read window contents"

### Phase 3: Overlay System (2-3 weeks)

5. **Create overlay window:**
   - Windows: winit + WS_EX_LAYERED
   - macOS: NSPanel
   - Linux: layer-shell (Wayland) + X11 overlay

6. **Command palette overlay:**
   - Transparent always-on-top window
   - Show available commands
   - Visual feedback for voice recognition

### Phase 4: App-Specific Support (ongoing)

7. **Priority apps:**
   1. **Browsers** (Chrome/Firefox via CDP)
   2. **VSCode** (extension API)
   3. **Terminal** (accessibility + text)
   4. **Godot** (internal GDScript API)
   5. **Blender** (Python API)
   6. **Adobe apps** (UXP/ExtendScript)

8. **App-specific grammars:**
   - Browser: tab management, navigation
   - VSCode: file operations, editing
   - Terminal: command execution

---

## 7. Known Limitations

### Platform-Specific

| Feature | Windows | macOS | Linux (X11) | Linux (Wayland) |
|---------|---------|-------|-------------|-----------------|
| Window enumeration | ✅ | ✅ | ✅ | ⚠️ KDE only |
| Accessibility API | ✅ UIA | ✅ AXUI | ✅ AT-SPI | ✅ AT-SPI |
| Overlay windows | ✅ | ✅ | ✅ | ⚠️ KDE/Sway only |
| Input injection | ✅ | ⚠️ perm | ✅ | ❌ |
| Active window detection | ✅ | ✅ | ✅ | ⚠️ KDE only |

### App-Specific

| App | Accessibility | API | Notes |
|-----|---------------|-----|-------|
| Chrome | ✅ | ✅ CDP | Best support |
| Firefox | ✅ | ✅ CDP | Marionette/CDP |
| VSCode | ✅ | ✅ Extension | Full control |
| Electron apps | ⚠️ | ❌ | Limited a11y |
| GTK apps | ✅ | ❌ | Good AT-SPI |
| Qt apps | ✅ | ❌ | Good AT-SPI |
| Games | ❌ | ❌ | OCR only |
| GNOME apps | ✅ | ❌ | AT-SPI works |

### General Limitations

1. **Wayland:** No standard window management API. Layer-shell for overlays only works on wlroots compositors (Sway, Hyprland, KDE). GNOME/Mutter provides no solution.

2. **macOS permissions:** Screen Recording required for window titles. Accessibility required for input simulation.

3. **Electron apps:** Accessibility support varies. Some expose full DOM, others are black boxes.

4. **Games:** Generally no accessibility API. OCR + image matching is the only option.

5. **UWP apps:** Different from Win32. Need separate handling for some features.

---

## 8. Code Examples

### Godot GDExtension Setup

**Cargo.toml:**
```toml
[package]
name = "careless_whisper_os"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
godot = { git = "https://github.com/godot-rust/gdext" }
active-win-pos-rs = "0.10"
```

**src/lib.rs:**
```rust
use godot::prelude::*;

mod window_manager;
mod accessibility;

#[gdextension]
unsafe impl ExtensionLibrary for CarelessWhisperOS {}
```

**src/window_manager.rs:**
```rust
use godot::prelude::*;
use active_win_pos_rs as awp;

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct WindowManager {
    base: Base<RefCounted>,
}

#[godot_api]
impl WindowManager {
    #[func]
    pub fn get_active_window(&self) -> Dictionary {
        let mut dict = Dictionary::new();
        match awp::get_active_window() {
            Ok(win) => {
                dict.set("title", win.title);
                dict.set("app_name", win.app_name);
                dict.set("process_id", win.process_id);
                dict.set("x", win.position.x);
                dict.set("y", win.position.y);
                dict.set("width", win.position.width);
                dict.set("height", win.position.height);
            }
            Err(_) => {
                godot_error!("Failed to get active window");
            }
        }
        dict
    }
    
    #[func]
    pub fn list_windows(&self) -> Array<Dictionary> {
        // Platform-specific implementation
        // Would need to extend active-win-pos-rs or implement directly
        Array::new()
    }
}
```

### GDScript Usage

```gdscript
extends Node

var window_manager = WindowManager.new()

func _ready():
    var active = window_manager.get_active_window()
    print("Active window: ", active.title)
    print("App: ", active.app_name)
    print("Position: ", active.x, ", ", active.y)
```

---

## 9. References

### Rust Libraries
- [active-win-pos-rs](https://github.com/dimusic/active-win-pos-rs) - Cross-platform active window
- [godot-rust/gdext](https://github.com/godot-rust/gdext) - Godot 4 GDExtension
- [winit](https://github.com/rust-windowing/winit) - Window creation
- [accesskit](https://github.com/AccessKit/accesskit) - Cross-platform accessibility

### Documentation
- [Microsoft UI Automation](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-uiautomationoverview)
- [macOS Accessibility Programming Guide](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/)
- [AT-SPI2](https://www.freedesktop.org/wiki/Accessibility/AT-SPI2/)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [wlr-layer-shell](https://wayland.app/protocols/wlr-layer-shell-unstable-v1)

### Projects
- [Talon Voice](https://talonvoice.com/) - Voice control reference
- [Hammerspoon](https://www.hammerspoon.org/) - macOS automation
- [AutoHotkey](https://www.autohotkey.com/) - Windows automation
- [Surfingkeys](https://github.com/brookhong/Surfingkeys) - Browser keyboard control
- [koverlay](https://github.com/erik96/koverlay) - Wayland overlay example

---

## 10. Priority Order for App Support

1. **VSCode** - Dev work, good API, high value
2. **Chrome/Firefox** - CDP, universal, web research
3. **Terminal** - Text-based, accessibility works well
4. **Godot** - Direct API, dogfooding
5. **Blender** - Python API, creative work
6. **Slack/Discord** - Electron, accessibility varies
7. **Adobe Photoshop** - UXP, specialized use
8. **Microsoft Office** - COM/VSTO, business use
9. **Figma** - Browser-based via CDP
10. **Games** - OCR only, low priority

---

*End of research document*
