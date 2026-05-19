## vim_controller.gd
## Handles vim mode commands via cross-platform input simulation.
## Uses OSController GDExtension (InputInjector/enigo) when available, falls back to xdotool on Linux.
extends Node

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

## Whether vim integration is enabled.
var enabled: bool = false

## Use native OSController input methods (cross-platform via enigo).
## Auto-detected in _ready() based on whether the InputInjector GDExtension is loaded.
var use_native_input: bool = false

## Path to xdotool binary (fallback for Linux without native support).
var xdotool_path: String = "xdotool"

## Whether to show debug output for executed commands.
var debug_output: bool = true

## Reference to WhisperCpp node for native input.
var _whisper_node: Node = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------


func _ready() -> void:
	CommandDispatcher.command_executed.connect(_on_command_executed)
	# Auto-detect native input via OSController GDExtension
	if ClassDB.class_exists("InputInjector"):
		use_native_input = true
		if debug_output:
			push_warning("[VimController] InputInjector available — native input enabled")


## Set the WhisperCpp node reference for native input methods.
func set_whisper_node(node: Node) -> void:
	_whisper_node = node
	if debug_output:
		push_warning("[VimController] WhisperNode set (transcription engine); native input via OSController: %s" % _has_native_input())


# ---------------------------------------------------------------------------
# Command handlers
# ---------------------------------------------------------------------------


func _on_command_executed(command_name: String, args: Dictionary) -> void:
	if not enabled:
		return

	match command_name:
		"vim_insert":
			_vim_insert_mode()
		"vim_normal":
			_vim_normal_mode()
		"type":
			if args.has("text"):
				_type_text(args["text"])
		"press":
			if args.has("key"):
				_press_key(args["key"])
		_:
			# Not a vim-related command, ignore
			pass


# ---------------------------------------------------------------------------
# Vim mode commands
# ---------------------------------------------------------------------------


func _vim_insert_mode() -> void:
	# In vim, pressing 'i' enters insert mode
	_press_key("i")
	if debug_output:
		push_warning("[VimController] Switched to insert mode")


func _vim_normal_mode() -> void:
	# In vim, pressing Escape enters normal mode
	_press_key("Escape")
	if debug_output:
		push_warning("[VimController] Switched to normal mode")


# ---------------------------------------------------------------------------
# Input execution (native or xdotool fallback)
# ---------------------------------------------------------------------------


## Check if native input methods are available.
func _has_native_input() -> bool:
	return use_native_input and has_node("/root/OSController") and OSController.input_injector != null


## Type text using native method or xdotool fallback.
func _type_text(text: String) -> void:
	if text.is_empty():
		return

	if _has_native_input():
		var success: bool = OSController.type_text(text)
		if debug_output:
			push_warning("[VimController] native type '%s' -> %s" % [text, success])
	else:
		# Fallback to xdotool (Linux only)
		var output: Array[String] = []
		var exit_code: int = OS.execute(xdotool_path, ["type", "--", text], output, true)
		if debug_output:
			push_warning("[VimController] xdotool type '%s' -> exit code %d" % [text, exit_code])


## Press a key using native method or xdotool fallback.
func _press_key(key: String) -> void:
	if key.is_empty():
		return

	if _has_native_input():
		var success: bool = OSController.press_key(key)
		if debug_output:
			push_warning("[VimController] native key '%s' -> %s" % [key, success])
	else:
		# Fallback to xdotool (Linux only)
		var output: Array[String] = []
		var exit_code: int = OS.execute(xdotool_path, ["key", key], output, true)
		if debug_output:
			push_warning("[VimController] xdotool key '%s' -> exit code %d" % [key, exit_code])


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


## Enable vim integration.
func enable() -> void:
	enabled = true
	if debug_output:
		push_warning("[VimController] Enabled (native: %s)" % _has_native_input())


## Disable vim integration.
func disable() -> void:
	enabled = false
	if debug_output:
		push_warning("[VimController] Disabled")


## Toggle vim integration.
func toggle() -> void:
	if enabled:
		disable()
	else:
		enable()


## Check if xdotool is available on the system (for fallback).
func is_xdotool_available() -> bool:
	var output: Array[String] = []
	var exit_code: int = OS.execute("which", [xdotool_path], output, true)
	return exit_code == 0


## Check if native input is ready to use.
func is_native_input_available() -> bool:
	return _has_native_input()
