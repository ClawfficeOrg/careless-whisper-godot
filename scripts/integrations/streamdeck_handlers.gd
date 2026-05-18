## streamdeck_handlers.gd
## Registry mapping StreamDeck action IDs to handler functions.
##
## Connects to StreamDeckServer.action_received and dispatches to the matching
## handler. Five sample action handlers are provided:
##
##   start_recording  — emit mic_started via SignalBus (non-blocking)
##   stop_recording   — emit mic_stopped via SignalBus (non-blocking)
##   toggle_mute      — toggle the mute config flag via ConfigManager
##   load_model       — forward model name to ModelManager.start_download
##   notify           — push a notification string via push_warning / SignalBus
##
## To add custom actions, call register_handler() before or after _ready().
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted after a handler runs. result contains {action_id, success, message}.
signal action_executed(action_id: String, result: Dictionary)

# ---------------------------------------------------------------------------
# Constants — built-in action IDs
# ---------------------------------------------------------------------------

const ACTION_START_RECORDING: String = "start_recording"
const ACTION_STOP_RECORDING: String = "stop_recording"
const ACTION_TOGGLE_MUTE: String = "toggle_mute"
const ACTION_LOAD_MODEL: String = "load_model"
const ACTION_NOTIFY: String = "notify"

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Maps action_id (String) → Callable
var _handlers: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------


func _ready() -> void:
	_register_default_handlers()
	if has_node("/root/StreamDeckServer"):
		StreamDeckServer.action_received.connect(_on_action_received)
	else:
		push_warning("[StreamDeckHandlers] StreamDeckServer autoload not found.")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Register a custom handler for action_id.
## handler must be a Callable that accepts (payload: Dictionary) -> Dictionary.
## Returns true if successfully registered, false if action_id already exists.


func register_handler(action_id: String, handler: Callable) -> bool:
	if _handlers.has(action_id):
		push_warning("[StreamDeckHandlers] Handler already registered for: " + action_id)
		return false
	_handlers[action_id] = handler
	return true


## Override an existing handler or register a new one.


func set_handler(action_id: String, handler: Callable) -> void:
	_handlers[action_id] = handler


## Returns the registered action IDs.


func get_action_ids() -> Array:
	return _handlers.keys()


## Manually invoke an action (useful for testing).
## Returns the result Dictionary from the handler, or an error dict.


func handle_action(action_id: String, payload: Dictionary) -> Dictionary:
	if not _handlers.has(action_id):
		var result: Dictionary = {
			"action_id": action_id,
			"success": false,
			"message": "Unknown action: " + action_id,
		}
		action_executed.emit(action_id, result)
		return result
	var handler: Callable = _handlers[action_id]
	var result: Dictionary = handler.call(payload)
	action_executed.emit(action_id, result)
	SignalBus.streamdeck_action_executed.emit(action_id, result)
	return result


# ---------------------------------------------------------------------------
# Internal — default handler registration
# ---------------------------------------------------------------------------


func _register_default_handlers() -> void:
	_handlers[ACTION_START_RECORDING] = _handle_start_recording
	_handlers[ACTION_STOP_RECORDING] = _handle_stop_recording
	_handlers[ACTION_TOGGLE_MUTE] = _handle_toggle_mute
	_handlers[ACTION_LOAD_MODEL] = _handle_load_model
	_handlers[ACTION_NOTIFY] = _handle_notify


# ---------------------------------------------------------------------------
# Internal — signal handler from StreamDeckServer
# ---------------------------------------------------------------------------


func _on_action_received(action_id: String, payload: Dictionary) -> void:
	call_deferred("handle_action", action_id, payload)


# ---------------------------------------------------------------------------
# Sample action handlers
# ---------------------------------------------------------------------------


func _handle_start_recording(_payload: Dictionary) -> Dictionary:
	SignalBus.mic_started.emit()
	push_warning("[StreamDeckHandlers] start_recording triggered via StreamDeck.")
	return {"action_id": ACTION_START_RECORDING, "success": true, "message": "Recording started"}


func _handle_stop_recording(_payload: Dictionary) -> Dictionary:
	SignalBus.mic_stopped.emit()
	push_warning("[StreamDeckHandlers] stop_recording triggered via StreamDeck.")
	return {"action_id": ACTION_STOP_RECORDING, "success": true, "message": "Recording stopped"}


func _handle_toggle_mute(_payload: Dictionary) -> Dictionary:
	var current_mute: bool = ConfigManager.get_value("audio.muted", false)
	var new_mute: bool = not current_mute
	ConfigManager.set_value("audio.muted", new_mute)
	var state: String = "muted" if new_mute else "unmuted"
	push_warning("[StreamDeckHandlers] toggle_mute -> " + state)
	return {
		"action_id": ACTION_TOGGLE_MUTE,
		"success": true,
		"message": "Audio " + state,
		"muted": new_mute,
	}


func _handle_load_model(payload: Dictionary) -> Dictionary:
	var model_name: String = payload.get("model", "")
	if model_name.is_empty():
		return {
			"action_id": ACTION_LOAD_MODEL,
			"success": false,
			"message": "Missing 'model' field in payload",
		}
	if not has_node("/root/ModelManager"):
		return {
			"action_id": ACTION_LOAD_MODEL,
			"success": false,
			"message": "ModelManager autoload not available",
		}
	ModelManager.start_download(model_name)
	push_warning("[StreamDeckHandlers] load_model requested: " + model_name)
	return {
		"action_id": ACTION_LOAD_MODEL,
		"success": true,
		"message": "Download started for model: " + model_name,
		"model": model_name,
	}


func _handle_notify(payload: Dictionary) -> Dictionary:
	var message: String = payload.get("message", "")
	if message.is_empty():
		return {
			"action_id": ACTION_NOTIFY,
			"success": false,
			"message": "Missing 'message' field in payload",
		}
	push_warning("[StreamDeckHandlers] notify: " + message)
	SignalBus.streamdeck_notification.emit(message)
	return {"action_id": ACTION_NOTIFY, "success": true, "message": message}
