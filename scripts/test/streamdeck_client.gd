## streamdeck_client.gd
## Utility class for sending test action payloads to the StreamDeck HTTP server.
##
## Use this in manual test scenes to POST example payloads without a real StreamDeck.
## All requests go to 127.0.0.1:PORT with optional secret header.
##
## Five sample payloads correspond to the five built-in StreamDeckHandlers actions:
##   send_start_recording()
##   send_stop_recording()
##   send_toggle_mute()
##   send_load_model(model_name)
##   send_notify(message)
extends RefCounted

class_name StreamDeckClient

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a response is received (or a connection error occurs).
signal request_completed(action_id: String, status_code: int, body: String)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

var port: int = 12138
var secret: String = ""

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const HOST: String = "127.0.0.1"

# ---------------------------------------------------------------------------
# Active request tracking
# ---------------------------------------------------------------------------

## Array of active HTTPRequest nodes owned by this client.
var _active_requests: Array = []
## Parent node to attach HTTPRequest children to (must be in scene tree).
var _parent_node: Node = null


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialize the client. parent_node must be in the scene tree so that
## HTTPRequest nodes can be added and processed.
func initialize(parent_node: Node) -> void:
	_parent_node = parent_node
	port = ProjectSettings.get_setting("streamdeck/port", 12138)
	secret = ProjectSettings.get_setting("streamdeck/secret", "")


## POST the start_recording action.
func send_start_recording() -> void:
	_post_action("start_recording", {})


## POST the stop_recording action.
func send_stop_recording() -> void:
	_post_action("stop_recording", {})


## POST the toggle_mute action.
func send_toggle_mute() -> void:
	_post_action("toggle_mute", {})


## POST the load_model action with the given model name.
func send_load_model(model_name: String) -> void:
	_post_action("load_model", {"model": model_name})


## POST the notify action with the given message.
func send_notify(message: String) -> void:
	_post_action("notify", {"message": message})


## POST an arbitrary action payload.
func send_action(action_id: String, extra: Dictionary) -> void:
	_post_action(action_id, extra)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _post_action(action_id: String, extra: Dictionary) -> void:
	if _parent_node == null:
		push_error("[StreamDeckClient] call initialize(parent_node) first.")
		return

	var payload: Dictionary = {"action": action_id}
	for key in extra.keys():
		payload[key] = extra[key]

	var body: String = JSON.stringify(payload)
	var url: String = "http://%s:%d/" % [HOST, port]

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Content-Length: " + str(body.length()),
	]
	if not secret.is_empty():
		headers.append("X-StreamDeck-Secret: " + secret)

	var req: HTTPRequest = HTTPRequest.new()
	_parent_node.add_child(req)
	_active_requests.append(req)

	req.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
			var resp_body: String = body_bytes.get_string_from_utf8()
			if result != HTTPRequest.RESULT_SUCCESS:
				push_warning(
					"[StreamDeckClient] Request failed (result %d) for action: %s"
					% [result, action_id]
				)
				request_completed.emit(action_id, -1, "Connection error")
			else:
				request_completed.emit(action_id, response_code, resp_body)
			req.queue_free()
			_active_requests.erase(req)
	)

	var err: Error = req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error(
			"[StreamDeckClient] Failed to send request for action %s: error %d"
			% [action_id, err]
		)
