# MacroManager

`MacroManager` is a global autoload (`scripts/autoload/macro_manager.gd`) that matches
voice transcription text against registered phrases and executes associated actions.

## Sample Macros

| Phrase | Name | Action |
|---|---|---|
| `hello computer` | `greeting` | Logs a greeting message via `push_warning` |
| `take screenshot` | `screenshot` | Placeholder — logs a screenshot request |
| `open browser` | `open_browser` | Calls `OS.shell_open("https://example.com")` |

## Signal

```gdscript
signal macro_triggered(macro_name: String, meta: Dictionary)
# meta["phrase"] — the normalised trigger phrase that matched
```

## API

```gdscript
MacroManager.register_macro(phrase, name, action_callable)
MacroManager.unregister_macro(phrase)
MacroManager.get_macro_phrases() -> Array
MacroManager.has_macro(phrase) -> bool
```

## How It Works

1. `MacroManager._ready()` registers the three sample macros and connects to
   `SignalBus.transcription_completed`.
2. Each transcription is lowercased and stripped; if it matches a registered phrase
   the corresponding `Callable` is invoked and `macro_triggered` is emitted.

## Manual Test

Open `scenes/test/macro_manager_test.tscn` in the Godot editor and press **F5** (or
use `./run.sh`). Click each button to simulate a transcription and confirm the
`StatusLabel` updates and the correct `push_warning` appears in the Output panel.
