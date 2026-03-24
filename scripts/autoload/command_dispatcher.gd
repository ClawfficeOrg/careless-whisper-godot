## command_dispatcher.gd
## Parses voice transcription text for commands and dispatches them.
## Connect to SignalBus.transcription_completed to receive text.
## Emits command_executed when a command is recognized.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a command is parsed and ready for execution.
## command_name: The command verb (e.g., "vim_insert", "type", "press")
## args: Dictionary with command-specific arguments
signal command_executed(command_name: String, args: Dictionary)

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

## Regex patterns for command parsing
var _vim_insert_pattern: RegEx
var _vim_normal_pattern: RegEx
var _type_pattern: RegEx
var _press_pattern: RegEx

# ---------------------------------------------------------------------------


func _ready() -> void:
	_compile_patterns()
	SignalBus.transcription_completed.connect(_on_transcription_completed)


func _compile_patterns() -> void:
	# Vim mode commands
	_vim_insert_pattern = RegEx.new()
	_vim_insert_pattern.compile("(?i)^\\s*(?:please\\s+)?(?:vim\\s+)?insert(?:\\s+mode)?\\s*$")

	_vim_normal_pattern = RegEx.new()
	_vim_normal_pattern.compile("(?i)^\\s*(?:please\\s+)?(?:vim\\s+)?normal(?:\\s+mode)?\\s*$")

	# Type command: "type hello world" or "type: hello world"
	_type_pattern = RegEx.new()
	_type_pattern.compile("(?i)^\\s*(?:please\\s+)?type\\s*[:]?\\s*(.+?)\\s*$")

	# Press command: "press escape" or "press enter"
	_press_pattern = RegEx.new()
	_press_pattern.compile("(?i)^\\s*(?:please\\s+)?press\\s+(.+?)\\s*$")


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
		# Remove the prefix
		clean_text = clean_text.substr(command_prefix.length()).strip_edges()

	# Try vim insert mode
	if _vim_insert_pattern.search(clean_text) != null:
		emit_command("vim_insert", {})
		return true

	# Try vim normal mode
	if _vim_normal_pattern.search(clean_text) != null:
		emit_command("vim_normal", {})
		return true

	# Try type command
	var type_match: RegExMatch = _type_pattern.search(clean_text)
	if type_match != null:
		var text_to_type: String = type_match.get_string(1)
		emit_command("type", {"text": text_to_type})
		return true

	# Try press command
	var press_match: RegExMatch = _press_pattern.search(clean_text)
	if press_match != null:
		var key_to_press: String = press_match.get_string(1)
		emit_command("press", {"key": _normalize_key(key_to_press)})
		return true

	return false


## Emit a command with normalized arguments.
func emit_command(command_name: String, args: Dictionary) -> void:
	command_executed.emit(command_name, args)
	print("[CommandDispatcher] Dispatched: %s %s" % [command_name, args])


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_transcription_completed(text: String) -> void:
	parse(text)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Normalize spoken key names to xdotool-compatible names.
func _normalize_key(spoken_key: String) -> String:
	var key: String = spoken_key.to_lower().strip_edges()

	# Common key name mappings
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

	# Single character keys pass through uppercase
	if key.length() == 1:
		return key.to_upper()

	# F-keys: f1 -> F1, f12 -> F12
	if key.begins_with("f") and key.length() <= 3:
		return key.to_upper()

	return key
