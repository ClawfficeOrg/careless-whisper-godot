## macro_manager.gd
## Autoload that registers voice-triggered macros and executes their actions.
## Three sample macros are pre-registered at startup. Custom macros can be
## persisted via ConfigManager under the "macros.*" key namespace.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a macro phrase is matched and its action has been called.
## macro_name: internal name of the macro; meta carries the matched phrase.
signal macro_triggered(macro_name: String, meta: Dictionary)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

## Registry: normalised phrase -> { "name": String, "action": Callable }
var _macros: Dictionary = {}



func _ready() -> void:
	_register_sample_macros()
	SignalBus.transcription_completed.connect(_on_transcription_completed)



# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Register a macro that fires when phrase is matched in a transcription.
## phrase is matched case-insensitively after stripping whitespace.
func register_macro(phrase: String, macro_name: String, action: Callable) -> void:
	_macros[phrase.to_lower().strip_edges()] = {"name": macro_name, "action": action}



## Remove a previously registered macro by its trigger phrase.
func unregister_macro(phrase: String) -> void:
	_macros.erase(phrase.to_lower().strip_edges())



## Return the list of currently registered trigger phrases.
func get_macro_phrases() -> Array:
	return _macros.keys()



## Return true when phrase matches a registered macro.
func has_macro(phrase: String) -> bool:
	return _macros.has(phrase.to_lower().strip_edges())



# ---------------------------------------------------------------------------
# Sample macros
# ---------------------------------------------------------------------------

func _register_sample_macros() -> void:
	register_macro("hello computer", "greeting", _action_greeting)
	register_macro("take screenshot", "screenshot", _action_screenshot)
	register_macro("open browser", "open_browser", _action_open_browser)



func _action_greeting() -> void:
	push_warning("[MacroManager] greeting — Hello, I'm listening!")



func _action_screenshot() -> void:
	push_warning("[MacroManager] screenshot — screenshot requested (placeholder)")



func _action_open_browser() -> void:
	OS.shell_open("https://example.com")
	push_warning("[MacroManager] open_browser — opened https://example.com")



# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_transcription_completed(text: String) -> void:
	var clean: String = text.to_lower().strip_edges()
	if not _macros.has(clean):
		return
	var entry: Dictionary = _macros[clean]
	var macro_name: String = entry["name"]
	var action: Callable = entry["action"]
	action.call()
	macro_triggered.emit(macro_name, {"phrase": clean})
	# Also route macro events through the global SignalBus for cross-boundary listeners
	if SignalBus != null:
		SignalBus.macro_triggered.emit(macro_name, {"phrase": clean})
