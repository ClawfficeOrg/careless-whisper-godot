## streamdeck_test.gd
## Manual test scene for StreamDeckServer and StreamDeckHandlers.
##
## Verification steps:
## 1. Run the scene — status label shows server port and listen state.
## 2. Click each sample action button — the log area shows the request
##    response and any handler output.
## 3. "Start Recording" / "Stop Recording" — verify SignalBus.mic_started /
##    mic_stopped are emitted (watch godot.log or connect debugger).
## 4. "Toggle Mute" — check that ConfigManager "audio.muted" toggles.
## 5. "Load Model (tiny.en)" — ModelManager.start_download is called;
##    observe download_started signal in the log.
## 6. "Send Notify" — observe the notification text in the log.
## 7. Optional: run `curl -X POST http://127.0.0.1:12138/ \
##      -H "Content-Type: application/json" \
##      -d '{"action":"notify","message":"hello"}'`
##    and verify the log updates.
extends Control

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

@onready var _status_label: Label = $VBox/StatusLabel
@onready var _log_text: TextEdit = $VBox/LogText
@onready var _start_btn: Button = $VBox/ButtonRow/StartRecordingBtn
@onready var _stop_btn: Button = $VBox/ButtonRow/StopRecordingBtn
@onready var _mute_btn: Button = $VBox/ButtonRow/ToggleMuteBtn
@onready var _model_btn: Button = $VBox/ButtonRow/LoadModelBtn
@onready var _notify_btn: Button = $VBox/ButtonRow/NotifyBtn

# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------

var _client: StreamDeckClient = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_client = StreamDeckClient.new()
	_client.initialize(self)
	_client.request_completed.connect(_on_request_completed)

	# Display server status
	if has_node("/root/StreamDeckServer"):
		var listening: bool = StreamDeckServer.is_listening()
		var port: int = StreamDeckServer.get_port()
		_status_label.text = (
			"StreamDeckServer: port %d — %s" % [port, "LISTENING" if listening else "NOT listening"]
		)
		StreamDeckServer.action_received.connect(_on_action_received)
	else:
		_status_label.text = "StreamDeckServer autoload NOT registered"

	# Display handler status
	if has_node("/root/StreamDeckHandlers"):
		StreamDeckHandlers.action_executed.connect(_on_action_executed)
		_log("StreamDeckHandlers ready with actions: "
			+ ", ".join(StreamDeckHandlers.get_action_ids()))
	else:
		_log("WARNING: StreamDeckHandlers autoload not registered")

	_start_btn.pressed.connect(_on_start_recording_pressed)
	_stop_btn.pressed.connect(_on_stop_recording_pressed)
	_mute_btn.pressed.connect(_on_toggle_mute_pressed)
	_model_btn.pressed.connect(_on_load_model_pressed)
	_notify_btn.pressed.connect(_on_notify_pressed)


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_start_recording_pressed() -> void:
	_log("→ Sending start_recording…")
	_client.send_start_recording()


func _on_stop_recording_pressed() -> void:
	_log("→ Sending stop_recording…")
	_client.send_stop_recording()


func _on_toggle_mute_pressed() -> void:
	_log("→ Sending toggle_mute…")
	_client.send_toggle_mute()


func _on_load_model_pressed() -> void:
	_log("→ Sending load_model (tiny.en)…")
	_client.send_load_model("tiny.en")


func _on_notify_pressed() -> void:
	_log("→ Sending notify…")
	_client.send_notify("Hello from StreamDeck test!")


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_request_completed(action_id: String, status_code: int, body: String) -> void:
	_log("  HTTP %d for '%s': %s" % [status_code, action_id, body])


func _on_action_received(action_id: String, payload: Dictionary) -> void:
	_log("  Server received action: %s payload=%s" % [action_id, str(payload)])


func _on_action_executed(action_id: String, result: Dictionary) -> void:
	_log("  Handler result for '%s': %s" % [action_id, str(result)])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _log(message: String) -> void:
	_log_text.text += message + "\n"
	_log_text.scroll_vertical = _log_text.get_line_count()
