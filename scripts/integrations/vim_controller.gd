## vim_controller.gd
## Handles vim mode commands by executing xdotool on Linux.
## Listens to CommandDispatcher for vim_insert, vim_normal, type, and press commands.
## Stub implementation - requires xdotool installed on the system.
extends Node

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

## Whether vim integration is enabled.
var enabled: bool = false

## Path to xdotool binary. Override if not in PATH.
var xdotool_path: String = "xdotool"

## Whether to show debug output for executed commands.
var debug_output: bool = true

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------


func _ready() -> void:
	CommandDispatcher.command_executed.connect(_on_command_executed)


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
		print("[VimController] Switched to insert mode")


func _vim_normal_mode() -> void:
	# In vim, pressing Escape enters normal mode
	_press_key("Escape")
	if debug_output:
		print("[VimController] Switched to normal mode")


# ---------------------------------------------------------------------------
# xdotool execution
# ---------------------------------------------------------------------------


## Type text using xdotool.
func _type_text(text: String) -> void:
	if text.is_empty():
		return

	# xdotool type -- works with any text
	var output: Array[String] = []
	var exit_code: int = OS.execute(xdotool_path, ["type", "--", text], output, true)

	if debug_output:
		print("[VimController] xdotool type '%s' -> exit code %d" % [text, exit_code])
		if output.size() > 0 and not output[0].is_empty():
			print("  Output: %s" % output[0])


## Press a key using xdotool.
func _press_key(key: String) -> void:
	if key.is_empty():
		return

	# xdotool key -- presses a key by name
	var output: Array[String] = []
	var exit_code: int = OS.execute(xdotool_path, ["key", key], output, true)

	if debug_output:
		print("[VimController] xdotool key '%s' -> exit code %d" % [key, exit_code])
		if output.size() > 0 and not output[0].is_empty():
			print("  Output: %s" % output[0])


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


## Enable vim integration.
func enable() -> void:
	enabled = true
	if debug_output:
		print("[VimController] Enabled")


## Disable vim integration.
func disable() -> void:
	enabled = false
	if debug_output:
		print("[VimController] Disabled")


## Toggle vim integration.
func toggle() -> void:
	if enabled:
		disable()
	else:
		enable()


## Check if xdotool is available on the system.
func is_xdotool_available() -> bool:
	var output: Array[String] = []
	var exit_code: int = OS.execute("which", [xdotool_path], output, true)
	return exit_code == 0
