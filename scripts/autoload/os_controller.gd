## os_controller.gd
## OSController - High-level OS control for voice commands.
##
## Provides convenient wrappers for window management and input injection
## with voice-friendly command parsing.
##
## NOTE: Must be an autoload Node so that _ready() and _process() are called
## by the scene tree. Extends Node instead of RefCounted.
extends Node

class_name OSController

var window_manager: Object = null
var input_injector: Object = null

signal command_executed(command: String, success: bool)
signal window_changed(window_info: Dictionary)
signal focus_window_result(success: bool, message: String)
## Emitted when the list of audio input devices changes.
signal device_list_changed(devices: Array)
## Emitted when the OS default audio input device changes.
signal default_device_changed(device_id: String)

## Seconds between audio-device list polls.
const DEVICE_POLL_INTERVAL: float = 2.0

var _last_window: Dictionary = {}
var _last_input_devices: Array[String] = []
var _last_default_input: String = ""
var _device_poll_timer: float = 0.0


func _ready() -> void:
	# Load GDExtension classes
	if ClassDB.class_exists("WindowManager"):
		window_manager = ClassDB.instantiate("WindowManager")
	else:
		push_error("WindowManager class not found - OS control GDExtension not loaded")

	if ClassDB.class_exists("InputInjector"):
		input_injector = ClassDB.instantiate("InputInjector")
	else:
		push_error("InputInjector class not found - OS control GDExtension not loaded")

	_check_active_window()



func _process(delta: float) -> void:
	_check_active_window()
	_device_poll_timer -= delta
	if _device_poll_timer <= 0.0:
		_device_poll_timer = DEVICE_POLL_INTERVAL
		_check_devices()


## Get current active window information.

func get_active_window() -> Dictionary:
	if not window_manager:
		return {"error": "WindowManager not available"}
	return window_manager.get_active_window()


## List all visible windows.

func list_windows() -> Array:
	if not window_manager:
		return []
	return window_manager.list_windows()


## Type a text string.

func type_text(text: String) -> bool:
	if not input_injector:
		push_error("InputInjector not available")
		return false
	var success: bool = input_injector.type_text(text)
	command_executed.emit("type_text: " + text, success)
	return success


## Press a key combination (e.g. "ctrl+c").

func press_key(key_combo: String) -> bool:
	if not input_injector:
		push_error("InputInjector not available")
		return false
	var success: bool = input_injector.press_key(key_combo)
	command_executed.emit("press_key: " + key_combo, success)
	return success


## Execute vim-style command.

func execute_vim_command(command: String) -> bool:
	var parts: PackedStringArray = command.split(" ", false, 1)
	if parts.is_empty():
		return false

	var cmd: String = parts[0].to_lower()
	var args: String = parts[1] if parts.size() > 1 else ""

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
		# Text input fallback
		_:
			if args.is_empty():
				return type_text(cmd)
			else:
				return type_text(args)

	return false


## Focus a window by title (case-insensitive substring match).
## Delegates to WindowManager.focus_window via the GDExtension.
## Emits focus_window_result(success, message) and routes via SignalBus.

func focus_window(window_name: String) -> bool:
	if not window_manager:
		var msg: String = "WindowManager not available"
		push_warning("[OSController] " + msg)
		focus_window_result.emit(false, msg)
		return false

	if not window_manager.has_method("focus_window"):
		var msg: String = "focus_window not supported by the loaded extension"
		push_warning("[OSController] " + msg)
		focus_window_result.emit(false, msg)
		return false

	var success: bool = window_manager.focus_window(window_name)
	var msg: String
	if success:
		msg = "Focused: " + window_name
	else:
		msg = "Failed to focus: " + window_name
	focus_window_result.emit(success, msg)
	command_executed.emit("focus_window: " + window_name, success)
	SignalBus.focus_window_result.emit(success, msg)
	return success


## Return a human-readable string describing the active window.

func announce_active_window() -> String:
	var win: Dictionary = get_active_window()
	if win.has("error"):
		return "Error: " + str(win.get("error", ""))

	var title: String = win.get("title", "")
	var app_name: String = win.get("app_name", "")
	var text: String = "Active window: %s" % title
	if not app_name.is_empty():
		text += " in %s" % app_name
	return text


## Poll for window changes and emit signal when they occur.

func _check_active_window() -> void:
	var current: Dictionary = get_active_window()
	if current.has("error"):
		return
	if _last_window.is_empty() or current.get("title", "") != _last_window.get("title", ""):
		_last_window = current
		window_changed.emit(current)


## Poll audio input devices for changes and emit signals when they occur.

func _check_devices() -> void:
	var devices: Array[String] = get_input_devices()
	if _input_devices_changed(devices):
		_last_input_devices = devices
		var as_array: Array = []
		for d: String in devices:
			as_array.append(d)
		device_list_changed.emit(as_array)

	var current_default: String = get_default_input_device()
	if current_default != _last_default_input:
		_last_default_input = current_default
		default_device_changed.emit(current_default)


## Return all available audio input device names.

func get_input_devices() -> Array[String]:
	var raw: PackedStringArray = AudioServer.get_input_device_list()
	var result: Array[String] = []
	for d: String in raw:
		result.append(d)
	return result


## Return the current default audio input device name.

func get_default_input_device() -> String:
	return AudioServer.input_device


func _input_devices_changed(new_devices: Array[String]) -> bool:
	if new_devices.size() != _last_input_devices.size():
		return true
	for i: int in range(new_devices.size()):
		if new_devices[i] != _last_input_devices[i]:
			return true
	return false


func _switch_to_insert_mode() -> bool:
	# Integrates with the modal engine; currently just presses 'i'
	return press_key("i")
