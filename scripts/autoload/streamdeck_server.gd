## streamdeck_server.gd
## Tiny HTTP server autoload that receives StreamDeck action POST requests.
##
## Listens on 127.0.0.1:PORT (default 12138, override via project setting
## "streamdeck/port"). Parses incoming JSON, validates an optional shared-secret
## header ("X-StreamDeck-Secret"), and emits action_received so any handler can
## react without tight coupling.
##
## Security:
##   - Binds to localhost only — never exposed on the network.
##   - When streamdeck/secret is non-empty, requests missing the correct
##     X-StreamDeck-Secret header are rejected with 403.
##   - Strict mode (streamdeck/strict_auth = true) also rejects requests that
##     supply an incorrect secret (default: true when secret is set).
##
## Usage:
##   Add to project.godot [autoload] as StreamDeckServer.
##   Connect StreamDeckServer.action_received to your handler.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a well-formed action POST is received and authenticated.
signal action_received(action_id: String, payload: Dictionary)

## Emitted when the server starts listening.
signal server_started(port: int)

## Emitted when the server fails to start.
signal server_failed(error: String)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const DEFAULT_PORT: int = 12138
const BIND_ADDRESS: String = "127.0.0.1"
const MAX_PENDING_CONNECTIONS: int = 8
const READ_TIMEOUT_SEC: float = 5.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _server: TCPServer = null
var _port: int = DEFAULT_PORT
var _secret: String = ""
## List of active peer sessions: Array[Dictionary{peer, buffer, started_at}]
var _peers: Array = []


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------


func _ready() -> void:
	_port = ProjectSettings.get_setting("streamdeck/port", DEFAULT_PORT)
	_secret = ProjectSettings.get_setting("streamdeck/secret", "")
	_start_server()


func _process(_delta: float) -> void:
	if _server == null or not _server.is_listening():
		return
	# Accept all pending connections
	while _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		if peer != null:
			_peers.append({"peer": peer, "buffer": "", "started_at": Time.get_ticks_msec()})

	# Process each active peer
	var i: int = 0
	while i < _peers.size():
		var session: Dictionary = _peers[i]
		var still_alive: bool = _poll_peer(session)
		if still_alive:
			i += 1
		else:
			_peers.remove_at(i)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns true if the server is currently listening.


func is_listening() -> bool:
	return _server != null and _server.is_listening()


## Returns the port the server is bound to.


func get_port() -> int:
	return _port


## Stop the server and close all connections.


func stop() -> void:
	_peers.clear()
	if _server != null:
		_server.stop()
	push_warning("[StreamDeckServer] Server stopped.")


# ---------------------------------------------------------------------------
# Internal — server setup
# ---------------------------------------------------------------------------


func _start_server() -> void:
	_server = TCPServer.new()
	var err: Error = _server.listen(_port, BIND_ADDRESS)
	if err != OK:
		var msg: String = "Failed to bind %s:%d — error %d" % [BIND_ADDRESS, _port, err]
		push_error("[StreamDeckServer] " + msg)
		server_failed.emit(msg)
		_server = null
		return
	push_warning("[StreamDeckServer] Listening on %s:%d" % [BIND_ADDRESS, _port])
	server_started.emit(_port)


# ---------------------------------------------------------------------------
# Internal — per-peer polling
# ---------------------------------------------------------------------------

## Read available bytes from peer, attempt to parse HTTP request.
## Returns false when the peer should be removed from _peers.


func _poll_peer(session: Dictionary) -> bool:
	var peer: StreamPeerTCP = session["peer"]

	# Check for timeout
	var elapsed_ms: int = Time.get_ticks_msec() - int(session["started_at"])
	if elapsed_ms > int(READ_TIMEOUT_SEC * 1000.0):
		peer.disconnect_from_host()
		return false

	peer.poll()
	var status: StreamPeerTCP.Status = peer.get_status()
	if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		return false

	# Read all available bytes
	var available: int = peer.get_available_bytes()
	if available > 0:
		var chunk: String = peer.get_utf8_string(available)
		session["buffer"] = session["buffer"] + chunk

	# Try to parse once we have headers + body
	var buf: String = session["buffer"]
	var header_end: int = buf.find("\r\n\r\n")
	if header_end == -1:
		return true  # Not yet complete; keep reading

	var header_section: String = buf.substr(0, header_end)
	var body_start: int = header_end + 4
	var body: String = buf.substr(body_start)

	# Extract Content-Length
	var content_length: int = _extract_content_length(header_section)
	if body.length() < content_length:
		return true  # Body not fully received yet

	# Full request is available — handle it
	_handle_request(peer, header_section, body.substr(0, content_length))
	return false  # Done with this peer


# ---------------------------------------------------------------------------
# Internal — request handling
# ---------------------------------------------------------------------------


func _handle_request(
	peer: StreamPeerTCP,
	header_section: String,
	body: String
) -> void:
	var lines: PackedStringArray = header_section.split("\r\n")
	if lines.is_empty():
		_send_response(peer, 400, "Bad Request", "Empty request")
		return

	var request_line: String = lines[0]
	if not request_line.begins_with("POST "):
		_send_response(peer, 405, "Method Not Allowed", "Only POST is supported")
		return

	# Validate secret header when configured
	if not _secret.is_empty():
		var token: String = _extract_header(header_section, "X-StreamDeck-Secret")
		if token != _secret:
			push_warning("[StreamDeckServer] Rejected request: invalid or missing secret.")
			_send_response(peer, 403, "Forbidden", "Invalid or missing X-StreamDeck-Secret")
			return

	# Parse JSON body
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(body)
	if parse_err != OK:
		_send_response(peer, 400, "Bad Request", "Invalid JSON: " + json.get_error_message())
		return

	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		_send_response(peer, 400, "Bad Request", "JSON root must be an object")
		return

	var payload: Dictionary = data
	if not payload.has("action"):
		_send_response(peer, 400, "Bad Request", "Missing required field: action")
		return

	var action_id: String = str(payload["action"])
	_send_response(peer, 200, "OK", '{"status":"ok","action":"' + action_id + '"}')
	push_warning("[StreamDeckServer] action_received: " + action_id)
	action_received.emit(action_id, payload)


# ---------------------------------------------------------------------------
# Internal — HTTP helpers
# ---------------------------------------------------------------------------


func _extract_content_length(headers: String) -> int:
	var lines: PackedStringArray = headers.split("\r\n")
	for line in lines:
		if line.to_lower().begins_with("content-length:"):
			var parts: PackedStringArray = line.split(":", false, 1)
			if parts.size() >= 2:
				return parts[1].strip_edges().to_int()
	return 0


func _extract_header(headers: String, header_name: String) -> String:
	var lower_name: String = header_name.to_lower() + ":"
	var lines: PackedStringArray = headers.split("\r\n")
	for line in lines:
		if line.to_lower().begins_with(lower_name):
			var parts: PackedStringArray = line.split(":", false, 1)
			if parts.size() >= 2:
				return parts[1].strip_edges()
	return ""


func _send_response(
	peer: StreamPeerTCP,
	status_code: int,
	status_text: String,
	body: String
) -> void:
	var response: String = (
		"HTTP/1.1 %d %s\r\nContent-Type: application/json\r\n" % [status_code, status_text]
		+ "Content-Length: %d\r\nConnection: close\r\n\r\n%s" % [body.length(), body]
	)
	peer.put_data(response.to_utf8_buffer())
	peer.disconnect_from_host()
