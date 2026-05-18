## command_dispatcher.gd
## Parses voice transcription text for commands and dispatches them.
## Connect to SignalBus.transcription_completed to receive text.
## Emits command_executed when a command is recognized.
## task-7: expanded with macro trigger patterns and window command patterns.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a command is parsed and ready for execution.
## command_name: The command verb (e.g., "vim_insert", "type", "press")
## args: Dictionary with command-specific arguments
signal command_executed(command_name: String, args: Dictionary)

## Emitted for every recognized command; also routed to SignalBus.
signal command_detected(command: String, args: Dictionary)

## Emitted when a macro trigger phrase is recognized.
signal macro_triggered(macro_id: String, context: Dictionary)

## Emitted when a window management command is recognized.
signal window_command(action: String, target: String, params: Dictionary)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

## Whether command parsing is enabled. When false, transcriptions pass through.
var enabled: bool = true

## Prefix that must appear before commands. Empty string for no prefix.
## Example: "computer, type hello" with prefix "computer" -> type command
var command_prefix: String = ""

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

## Regex patterns — core commands
var _vim_insert_pattern: RegEx
var _vim_normal_pattern: RegEx
var _type_pattern: RegEx
var _press_pattern: RegEx

## Regex patterns — macro triggers (task-7)
var _macro_trigger_pattern: RegEx

## Regex patterns — window commands (task-7)
var _focus_side_pattern: RegEx
var _focus_pattern: RegEx
var _win_action_pattern: RegEx
var _move_side_pattern: RegEx
var _move_pixels_pattern: RegEx

# ---------------------------------------------------------------------------


func _ready() -> void:
	_compile_patterns()
	SignalBus.transcription_completed.connect(_on_transcription_completed)


func _compile_patterns() -> void:
	# Vim mode commands
	_vim_insert_pattern = RegEx.new()
	_vim_insert_pattern.compile(
		"(?i)^\\s*(?:please\\s+)?(?:vim\\s+)?insert(?:\\s+mode)?\\s*$"
	)

	_vim_normal_pattern = RegEx.new()
	_vim_normal_pattern.compile(
		"(?i)^\\s*(?:please\\s+)?(?:vim\\s+)?normal(?:\\s+mode)?\\s*$"
	)

	# Type command: "type hello world" or "type: hello world"
	_type_pattern = RegEx.new()
	_type_pattern.compile("(?i)^\\s*(?:please\\s+)?type\\s*[:]?\\s*(.+?)\\s*$")

	# Press command: "press escape" or "press enter"
	_press_pattern = RegEx.new()
	_press_pattern.compile("(?i)^\\s*(?:please\\s+)?press\\s+(.+?)\\s*$")

	# Macro trigger: "run macro {id}" or "execute macro {id}"
	_macro_trigger_pattern = RegEx.new()
	_macro_trigger_pattern.compile(
		"(?i)^\\s*(?:run|execute)\\s+macro\\s+([\\w][\\w\\s]*?)\\s*$"
	)

	# Window focus with side: "focus terminal on left"
	_focus_side_pattern = RegEx.new()
	_focus_side_pattern.compile(
		"(?i)^\\s*focus\\s+(.+?)\\s+on\\s+(?:the\\s+)?(left|right|top|bottom)\\s*$"
	)

	# Window focus: "focus terminal" or "switch to firefox"
	_focus_pattern = RegEx.new()
	_focus_pattern.compile(
		"(?i)^\\s*(?:focus|switch\\s+to)\\s+(.+?)(?:\\s+window)?\\s*$"
	)

	# Window action: "close terminal" / "minimize browser" / "maximize editor"
	_win_action_pattern = RegEx.new()
	_win_action_pattern.compile(
		"(?i)^\\s*(close|minimize|maximize)\\s+(.+?)(?:\\s+window)?\\s*$"
	)

	# Move window to side: "move window to the left"
	_move_side_pattern = RegEx.new()
	_move_side_pattern.compile(
		"(?i)^\\s*move\\s+(?:the\\s+)?window\\s+to\\s+(?:the\\s+)?(left|right|top|bottom)\\s*$"
	)

	# Move window N pixels: "move window three pixels right"
	_move_pixels_pattern = RegEx.new()
	_move_pixels_pattern.compile(
		"(?i)^\\s*move\\s+window\\s+(\\w+)\\s+pixels?\\s+(left|right|up|down)\\s*$"
	)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Parse transcription text for commands.
## Returns true if a command was found and dispatched.
func parse(text: String) -> bool:
	if not enabled or text.is_empty():
		return false

	var clean_text: String = text.strip_edges()

	# Handle command prefix if configured
	if not command_prefix.is_empty():
		if not clean_text.to_lower().begins_with(command_prefix.to_lower()):
			return false
		clean_text = clean_text.substr(command_prefix.length()).strip_edges()

	var macro_enabled: bool = ConfigManager.get_value(
		"command.macro_triggers_enabled", true
	)
	var window_enabled: bool = ConfigManager.get_value(
		"command.window_commands_enabled", true
	)

	# --- Macro triggers ---
	if macro_enabled:
		var macro_m: RegExMatch = _macro_trigger_pattern.search(clean_text)
		if macro_m != null:
			var macro_id: String = macro_m.get_string(1).strip_edges()
			_emit_macro_triggered(macro_id, {"phrase": clean_text})
			return true

	# --- Window commands ---
	if window_enabled:
		# Focus with side: "focus terminal on left"
		var focus_side_m: RegExMatch = _focus_side_pattern.search(clean_text)
		if focus_side_m != null:
			var target: String = focus_side_m.get_string(1).strip_edges()
			var side: String = focus_side_m.get_string(2).to_lower()
			_emit_window_command("focus", target, {"side": side})
			return true

		# Focus without side: "focus terminal" or "switch to firefox"
		var focus_m: RegExMatch = _focus_pattern.search(clean_text)
		if focus_m != null:
			var target: String = focus_m.get_string(1).strip_edges()
			_emit_window_command("focus", target, {})
			return true

		# Window action: close / minimize / maximize
		var win_action_m: RegExMatch = _win_action_pattern.search(clean_text)
		if win_action_m != null:
			var action: String = win_action_m.get_string(1).to_lower()
			var target: String = win_action_m.get_string(2).strip_edges()
			_emit_window_command(action, target, {})
			return true

		# Move to side: "move window to the left"
		var move_side_m: RegExMatch = _move_side_pattern.search(clean_text)
		if move_side_m != null:
			var side: String = move_side_m.get_string(1).to_lower()
			_emit_window_command("move", "window", {"side": side})
			return true

		# Move pixels: "move window three pixels right"
		var move_px_m: RegExMatch = _move_pixels_pattern.search(clean_text)
		if move_px_m != null:
			var amount_word: String = move_px_m.get_string(1)
			var direction: String = move_px_m.get_string(2).to_lower()
			var pixels: int = _word_to_int(amount_word)
			_emit_window_command("move", "window", {"pixels": pixels, "direction": direction})
			return true

	# --- Vim mode commands ---
	if _vim_insert_pattern.search(clean_text) != null:
		emit_command("vim_insert", {})
		return true

	if _vim_normal_pattern.search(clean_text) != null:
		emit_command("vim_normal", {})
		return true

	# --- Type command ---
	var type_match: RegExMatch = _type_pattern.search(clean_text)
	if type_match != null:
		var text_to_type: String = type_match.get_string(1)
		emit_command("type", {"text": text_to_type})
		return true

	# --- Press command ---
	var press_match: RegExMatch = _press_pattern.search(clean_text)
	if press_match != null:
		var key_to_press: String = press_match.get_string(1)
		emit_command("press", {"key": _normalize_key(key_to_press)})
		return true

	return false


## Inject a transcript string directly (bypasses SignalBus).
## Useful for testing and scripted playback.
func receive_transcript(text: String) -> void:
	parse(text)


## Emit a command with normalized arguments.
func emit_command(command_name: String, args: Dictionary) -> void:
	command_executed.emit(command_name, args)
	command_detected.emit(command_name, args)
	SignalBus.command_detected.emit(command_name, args)
	push_warning("[CommandDispatcher] Dispatched: %s %s" % [command_name, args])


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_transcription_completed(text: String) -> void:
	parse(text)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _emit_window_command(action: String, target: String, params: Dictionary) -> void:
	window_command.emit(action, target, params)
	SignalBus.window_command.emit(action, target, params)
	push_warning(
		"[CommandDispatcher] window_command: %s %s %s" % [action, target, params]
	)


func _emit_macro_triggered(macro_id: String, context: Dictionary) -> void:
	macro_triggered.emit(macro_id, context)
	SignalBus.macro_triggered.emit(macro_id, context)
	push_warning(
		"[CommandDispatcher] macro_triggered: %s %s" % [macro_id, context]
	)


## Normalize spoken key names to xdotool-compatible names.
func _normalize_key(spoken_key: String) -> String:
	var key: String = spoken_key.to_lower().strip_edges()

	var key_map: Dictionary = {
		"escape": "Escape",
		"esc": "Escape",
		"enter": "Return",
		"return": "Return",
		"tab": "Tab",
		"space": "space",
		"backspace": "BackSpace",
		"delete": "Delete",
		"del": "Delete",
		"up": "Up",
		"down": "Down",
		"left": "Left",
		"right": "Right",
		"home": "Home",
		"end": "End",
		"page up": "Page_Up",
		"page down": "Page_Down",
		"control": "Control_L",
		"ctrl": "Control_L",
		"alt": "Alt_L",
		"shift": "Shift_L",
		"super": "Super_L",
		"meta": "Super_L",
		"command": "Super_L",
	}

	if key_map.has(key):
		return key_map[key]

	if key.length() == 1:
		return key.to_upper()

	# F-keys: f1 -> F1, f12 -> F12
	if key.begins_with("f") and key.length() <= 3:
		return key.to_upper()

	return key


## Convert a spoken number word or digit string to an integer.
## Returns -1 if the word is not recognized.
func _word_to_int(word: String) -> int:
	var clean: String = word.to_lower().strip_edges()
	var num_words: Dictionary = {
		"one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
		"six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
		"eleven": 11, "twelve": 12, "fifteen": 15, "twenty": 20,
		"fifty": 50, "hundred": 100,
	}
	if num_words.has(clean):
		return num_words[clean]
	if clean.is_valid_int():
		return clean.to_int()
	return -1
