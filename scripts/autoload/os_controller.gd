extends RefCounted
class_name OSController

## OSController - High-level OS control for voice commands
##
## Provides convenient wrappers for window management and input injection
## with voice-friendly command parsing.

var window_manager: RefCounted
var input_injector: RefCounted

signal command_executed(command: String, success: bool)
signal window_changed(window_info: Dictionary)

var _last_window: Dictionary = {}

func _init():
	# Load GDExtension classes
	if ClassDB.class_exists("WindowManager"):
		window_manager = ClassDB.instantiate("WindowManager")
	else:
		push_error("WindowManager class not found - OS control GDExtension not loaded")

	if ClassDB.class_exists("InputInjector"):
		input_injector = ClassDB.instantiate("InputInjector")
	else:
		push_error("InputInjector class not found - OS control GDExtension not loaded")

func _ready():
	# Poll for window changes
	_check_active_window()

func _process(_delta):
	_check_active_window()

## Get current active window information
func get_active_window() -> Dictionary:
	if not window_manager:
		return {"error": "WindowManager not available"}

	return window_manager.get_active_window()

## List all visible windows
func list_windows() -> Array:
	if not window_manager:
		return []

	return window_manager.list_windows()

## Type text string
func type_text(text: String) -> bool:
	if not input_injector:
		push_error("InputInjector not available")
		return false

	var success = input_injector.type_text(text)
	command_executed.emit("type_text: " + text, success)
	return success

## Press key combination
func press_key(key_combo: String) -> bool:
	if not input_injector:
		push_error("InputInjector not available")
		return false

	var success = input_injector.press_key(key_combo)
	command_executed.emit("press_key: " + key_combo, success)
	return success

## Execute vim-style command
func execute_vim_command(command: String) -> bool:
	# Parse vim-style commands
	var parts = command.split(" ", false, 1)
	if parts.is_empty():
		return false

	var cmd = parts[0].to_lower()
	var args = parts[1] if parts.size() > 1 else ""

	match cmd:
		# Navigation
		"w", "write":
			return press_key("ctrl+s")
		"q", "quit":
			return press_key("alt+f4")
		"bn", "bnext":
			return press_key("ctrl+tab")
		"bp", "bprev":
			return press_key("ctrl+shift+tab")
		"bd", "bdelete":
			return press_key("ctrl+w")

		# Editing
		"yy", "yank":
			return press_key("ctrl+c")
		"p", "paste":
			return press_key("ctrl+v")
		"u", "undo":
			return press_key("ctrl+z")
		"r", "redo":
			return press_key("ctrl+y")
		"d", "delete":
			return press_key("delete")

		# Mode switching
		"i", "insert":
			return _switch_to_insert_mode()
		"esc", "normal":
			return press_key("escape")
		":", "command":
			return press_key("shift+;")

		# Text input
		_:
			if args.is_empty():
				return type_text(cmd)
			else:
				return type_text(args)

	return false

## Focus window by name
func focus_window(window_name: String) -> bool:
	var windows = list_windows()
	for win in windows:
		if win.title.to_lower().contains(window_name.to_lower()):
			# TODO: Implement window focusing
			push_warning("Window focusing not yet implemented")
			return false

	push_warning("Window not found: " + window_name)
	return false

## Announce active window (accessibility)
func announce_active_window() -> String:
	var win = get_active_window()
	if win.has("error"):
		return "Error: " + win.error

	var text = "Active window: %s" % win.title
	if not win.app_name.is_empty():
		text += " in %s" % win.app_name

	return text

## Check for window changes and emit signal
func _check_active_window():
	var current = get_active_window()
	if current.has("error"):
		return

	if _last_window.is_empty() or current.title != _last_window.title:
		_last_window = current
		window_changed.emit(current)

func _switch_to_insert_mode() -> bool:
	# This would integrate with the modal engine
	# For now, just press 'i' key
	return press_key("i")
