## mic_manager.gd
## MicManager — central mic lifecycle and hot-swap autoload.
##
## Manages a state machine for microphone connectivity:
##   IDLE → ACTIVE → RECONNECTING → ACTIVE (or DISCONNECTED on timeout)
##
## Device-change events arrive from OSController signals (polled every 2 s).
## Reconnect-progress is emitted on _process using elapsed time.
##
## Usage:
##   MicManager.get_state_name()          → "IDLE" / "ACTIVE" / etc.
##   MicManager.get_current_device()      → "Default" or device name
##   MicManager.get_device_list()         → Array[String]
##   MicManager.debug_simulate_disconnect()
##   MicManager.debug_simulate_reconnect()
extends Node


enum State {
	IDLE,
	ACTIVE,
	DISCONNECTED,
	RECONNECTING,
}

## Total seconds before reconnect is considered failed.
const MAX_RECONNECT_TIME: float = 30.0

## Seconds between reconnect-progress signal emissions.
const PROGRESS_EMIT_INTERVAL: float = 0.25

signal mic_disconnected(device_id: String)
signal mic_reconnected(device_id: String)
signal reconnect_progress(percent: float)
signal state_changed(new_state: String)
signal device_list_changed(devices: Array)

var _state: State = State.IDLE
var _current_device: String = ""
var _known_devices: Array[String] = []
var _reconnect_elapsed: float = 0.0
var _progress_emit_timer: float = 0.0


func _ready() -> void:
	SignalBus.mic_started.connect(_on_mic_started)
	SignalBus.mic_stopped.connect(_on_mic_stopped)

	if has_node("/root/OSController"):
		OSController.device_list_changed.connect(_on_device_list_changed)
		OSController.default_device_changed.connect(_on_default_device_changed)
	else:
		push_warning("[MicManager] OSController not available — device polling disabled")

	_refresh_device_list()


func _process(delta: float) -> void:
	if _state != State.RECONNECTING:
		return

	_reconnect_elapsed += delta
	_progress_emit_timer -= delta

	if _progress_emit_timer <= 0.0:
		_progress_emit_timer = PROGRESS_EMIT_INTERVAL
		var pct: float = minf(_reconnect_elapsed / MAX_RECONNECT_TIME * 100.0, 99.0)
		reconnect_progress.emit(pct)
		SignalBus.mic_reconnect_progress.emit(pct)

	if _reconnect_elapsed >= MAX_RECONNECT_TIME:
		push_warning(
			"[MicManager] Reconnect timed out after %.0f s" % MAX_RECONNECT_TIME
		)
		reconnect_progress.emit(0.0)
		SignalBus.mic_reconnect_progress.emit(0.0)
		_set_state(State.DISCONNECTED)


# ---------------------------------------------------------------------------
# OSController signal handlers
# ---------------------------------------------------------------------------

func _on_device_list_changed(devices: Array) -> void:
	var typed: Array[String] = []
	for d: Variant in devices:
		typed.append(str(d))
	_known_devices = typed
	device_list_changed.emit(devices)
	SignalBus.mic_device_list_changed.emit(devices)

	match _state:
		State.ACTIVE:
			if not _is_device_available(_current_device, _known_devices):
				_enter_reconnecting()
		State.RECONNECTING:
			if _is_device_available(_current_device, _known_devices):
				_enter_active()


func _on_default_device_changed(device_id: String) -> void:
	if _state == State.RECONNECTING and (
		device_id == _current_device or _current_device == "Default"
	):
		_enter_active()


# ---------------------------------------------------------------------------
# SignalBus mic lifecycle handlers
# ---------------------------------------------------------------------------

func _on_mic_started() -> void:
	_current_device = AudioServer.input_device
	if _current_device.is_empty():
		_current_device = "Default"
	_refresh_device_list()
	_set_state(State.ACTIVE)


func _on_mic_stopped() -> void:
	_set_state(State.IDLE)


# ---------------------------------------------------------------------------
# State transitions
# ---------------------------------------------------------------------------

func _enter_reconnecting() -> void:
	_reconnect_elapsed = 0.0
	_progress_emit_timer = 0.0
	var device: String = _current_device
	push_warning("[MicManager] Mic disconnected: %s" % device)
	mic_disconnected.emit(device)
	SignalBus.mic_device_disconnected.emit(device)
	_set_state(State.RECONNECTING)


func _enter_active() -> void:
	_reconnect_elapsed = 0.0
	_progress_emit_timer = 0.0
	reconnect_progress.emit(100.0)
	SignalBus.mic_reconnect_progress.emit(100.0)
	var device: String = _current_device
	push_warning("[MicManager] Mic reconnected: %s" % device)
	_set_state(State.ACTIVE)
	mic_reconnected.emit(device)
	SignalBus.mic_device_reconnected.emit(device)


func _set_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state
	var name: String = _state_to_string(new_state)
	state_changed.emit(name)
	SignalBus.mic_state_changed.emit(name)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _refresh_device_list() -> void:
	var raw: PackedStringArray = AudioServer.get_input_device_list()
	_known_devices = []
	for d: String in raw:
		_known_devices.append(d)


func _is_device_available(device_id: String, devices: Array[String]) -> bool:
	if device_id.is_empty() or device_id == "Default":
		return not devices.is_empty()
	return device_id in devices


func _state_to_string(s: State) -> String:
	match s:
		State.IDLE:
			return "IDLE"
		State.ACTIVE:
			return "ACTIVE"
		State.DISCONNECTED:
			return "DISCONNECTED"
		State.RECONNECTING:
			return "RECONNECTING"
	return "UNKNOWN"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Return the current state as a human-readable string.
func get_state_name() -> String:
	return _state_to_string(_state)


## Return the name of the device currently being monitored.
func get_current_device() -> String:
	return _current_device


## Return a copy of the known input device list.
func get_device_list() -> Array[String]:
	return _known_devices.duplicate()


## Force an immediate device-list refresh (useful for test scenes and UI).
func poll_now() -> void:
	_refresh_device_list()
	var devices: Array = []
	for d: String in _known_devices:
		devices.append(d)
	device_list_changed.emit(devices)
	SignalBus.mic_device_list_changed.emit(devices)


## Debug: simulate a mic disconnect (test scenes only).
func debug_simulate_disconnect() -> void:
	if _state == State.ACTIVE:
		_enter_reconnecting()


## Debug: simulate a mic reconnect (test scenes only).
func debug_simulate_reconnect() -> void:
	if _state == State.RECONNECTING or _state == State.DISCONNECTED:
		_enter_active()
