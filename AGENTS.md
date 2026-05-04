# AGENTS.md - AI Agent Guidelines

This file provides guidance for AI agents (Claude, GPT, etc.) working on this codebase.

## Project Overview

Careless Whisper is a **Godot 4.6** project that provides speech recognition using
whisper.cpp via a GDExtension (Rust, using `godot-rs` 0.4 / `gdext`).

The project consists of two sibling repos:

```
clawffice/
├── careless-whisper-godot/   ← this repo (Godot 4.6 project)
└── whisper.cpp/              ← whisper.cpp fork with Rust GDExtension
    └── godot-extension/      ← Rust source for WhisperCpp GDExtension
```

## Before Committing

**Always run the linter before committing GDScript changes:**

```bash
./scripts/lint.sh
```

For CI/CD or pre-commit hooks, use `--strict` to fail on errors:

```bash
./scripts/lint.sh --strict
```

## GDScript Godot 4.6 Compatibility Rules

### Type Annotations Required

All public functions **must** have explicit return type annotations:

```gdscript
# Bad — Godot 3 style
func _ready():
func start_recording():

# Good — Godot 4 style
func _ready() -> void:
func start_recording() -> void:
```

### Type Inference (`:=`)

When using `:=` type inference, be careful with:

1. **Dictionary access** — Returns `Variant`, needs explicit type:
   ```gdscript
   # Bad: infers as Variant
   var value := my_dict["key"]

   # Good: explicit type
   var value: String = my_dict["key"]
   # or use .get() with default
   var value: String = my_dict.get("key", "")
   ```

2. **Array access** — Returns `Variant` for untyped arrays:
   ```gdscript
   # Bad: infers as Variant
   var item := my_array[0]

   # Good: explicit type or typed array
   var item: String = my_array[0]
   # or
   var items: Array[String] = ["a", "b"]
   var item := items[0]  # OK: infers as String
   ```

3. **Method calls on untyped variables** — Return type may be `Variant`:
   ```gdscript
   # If _whisper is untyped Node
   var result := _whisper.load_model(path)  # Bad

   # Better: explicit type
   var result: bool = _whisper.load_model(path)
   ```

### `@onready` — Only for Scene-Tree Node References

`@onready` is evaluated when the node enters the scene tree and resolves `$NodePath`
references. Do **not** use it on plain object construction:

```gdscript
# Bad — StyleBoxFlat is not a node path, @onready is misleading
@onready var _style_box: StyleBoxFlat = StyleBoxFlat.new()

# Good — plain var, initialized at class load time
var _style_box: StyleBoxFlat = StyleBoxFlat.new()
```

### GDExtension Class Instantiation

Never use `SomeExtensionClass.new()` directly at class level — the extension may not
be loaded yet when the script is parsed. Always guard with `ClassDB.class_exists()`:

```gdscript
# Bad — crashes if extension not loaded
@onready var injector := InputInjector.new()

# Good — safe guard
var _injector: Object = null

func _ready() -> void:
    if ClassDB.class_exists("InputInjector"):
        _injector = ClassDB.instantiate("InputInjector")
    else:
        push_warning("InputInjector not available")
```

`ClassDB.instantiate()` returns `Object`, not `RefCounted`. Do not cast with
`as RefCounted` — use `Object` type or a more specific GDExtension base type if known.

### Dictionary Key Access

Never access Dictionary keys with dot notation (`win.title`) — that is invalid
GDScript syntax. Always use `[]` indexing or `.get()` with a default:

```gdscript
# Bad — looks like Godot 3 / Python, not valid GDScript
var t = win.title

# Good
var t: String = win["title"]
var t: String = win.get("title", "")
```

### `DirAccess` Virtual Paths (`user://`, `res://`)

`DirAccess.dir_exists_absolute()` and `DirAccess.make_dir_recursive_absolute()` require
**native** (globalized) paths. For `user://` paths use `DirAccess.open()` to check
existence, and `ProjectSettings.globalize_path()` before calling `_absolute` methods:

```gdscript
# Bad — user:// is a virtual path, not a native path
if not DirAccess.dir_exists_absolute("user://models"):
    DirAccess.make_dir_recursive_absolute("user://models")

# Good
if DirAccess.open("user://models") == null:
    DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path("user://models")
    )
```

## Code Style

- Use explicit types for all function signatures and variable declarations
- Use `:=` only when the type is unambiguous (literals, typed method returns)
- Keep lines under 100 characters
- Use snake_case for functions and variables
- Use PascalCase for classes and signals
- Two blank lines between top-level functions (GDScript convention)

## Project Structure

```
scripts/
├── autoload/           # Global singletons (SignalBus, ConfigManager, ModelManager,
│                       #   CommandDispatcher, OSController)
├── integrations/       # vim_controller.gd
├── ui/                 # UI components (main, config_dialog, model_browser,
│                       #   MicMeter, mic_level_meter, loading_overlay)
└── test/               # Manual test scenes

scenes/
├── main.tscn           # Main application scene (root: Control → WhisperNode)
├── main_scene.tscn     # Alternate layout scene
├── example.tscn        # Simple placeholder example
├── ui/
│   └── MicMeter.tscn   # Standalone mic meter UI component
└── test/
    └── input_injector_test.tscn

addons/
├── whisper_cpp/        # GDExtension for whisper.cpp (WhisperCpp class)
│   ├── whisper_cpp.gdextension
│   └── bin/            # Compiled .so/.dll/.framework files go here (gitignored)
└── os_control/         # GDExtension for OS window/input control
    ├── os_control.gdextension
    ├── Cargo.toml
    ├── src/
    │   ├── lib.rs
    │   ├── window_manager.rs
    │   └── input_injector.rs
    └── bin/            # Compiled DLLs go here (gitignored)
```

## Autoloads (project.godot)

| Name | Path | Purpose |
|------|------|---------|
| `SignalBus` | `scripts/autoload/signal_bus.gd` | Decoupled signal routing |
| `ConfigManager` | `scripts/autoload/config_manager.gd` | Persistent config (ConfigFile) |
| `ModelManager` | `scripts/autoload/model_manager.gd` | Model download/discovery |
| `CommandDispatcher` | `scripts/autoload/command_dispatcher.gd` | Voice command parsing |
| `VimController` | `scripts/integrations/vim_controller.gd` | Vim integration (xdotool/native) |

## Running the Project

```bash
./run.sh
```

Or in Godot editor: open project and press F5.

## GDExtension Notes

- `whisper_cpp.gdextension` — `compatibility_minimum = "4.3"` (works in 4.6)
- `os_control.gdextension` — `compatibility_minimum = "4.1"` (works in 4.6)
- Both use `entry_symbol = "gdext_rust_init"` (godot-rs 0.4 / gdext)
- If neither extension is compiled, the project runs in **placeholder mode** — UI loads
  but transcription and OS control are stubbed out
- **Stale DLL trap:** if you see `"X is not yet implemented"` from an extension that
  has source code for that feature, the compiled DLL in `bin/` predates the code.
  Rebuild with `cargo build --release` and copy the new DLL into `bin/<platform>/`.

### `.tscn` Scene File Common Pitfalls

Godot 4 `format=3` scene files have strict syntax rules:

```
# Bad — missing attributes, inline ExtResource path, wrong parent name
[gd_scene]
[node name="Child" instance=ExtResource(res://scenes/Foo.tscn) parent="Root"]

# Good — proper header, declared ext_resource block, dot-parent
[gd_scene load_steps=2 format=3]
[ext_resource type="PackedScene" path="res://scenes/Foo.tscn" id="1_foo"]
[node name="Root" type="Node"]
[node name="Child" parent="." instance=ExtResource("1_foo")]
```

- `[gd_scene]` **must** have `load_steps=N format=3`
- `ExtResource` must be declared as a separate `[ext_resource ...]` block and
  referenced by quoted id string — never as an inline path
- Direct children of the scene root use `parent="."` not `parent="RootNodeName"`

## whisper.cpp Fork

The `WhisperCpp` GDExtension is built from the `godot-whisper-cpp-node` branch of
`ClawfficeOrg/whisper.cpp`. See `BUILD.md` (Linux) and `BUILD_WINDOWS.md` (Windows)
for build instructions.

## API (WhisperCpp GDExtension)

```gdscript
whisper.load_model(path: String) -> bool   # Non-blocking; emits model_loaded or error
whisper.transcribe(bytes: PackedByteArray) # Non-blocking; emits transcription_complete
whisper.is_model_loaded() -> bool
whisper.is_transcribing() -> bool
whisper.language: String                   # e.g. "en"
whisper.threads: int                       # inference threads

signal model_loaded(path: String)
signal transcription_complete(text: String)
signal transcription_error(msg: String)
```
