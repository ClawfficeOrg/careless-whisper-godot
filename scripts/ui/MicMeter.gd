## MicMeter.gd
## Mic level display with device-status indicator.
## Receives RMS values via SignalBus.audio_level.
## Receives device-status updates via SignalBus mic hot-swap signals.
## Does NOT consume audio frames; audio capture is owned by main.gd.
extends Control

@onready var _progress_bar: ProgressBar = $VBox/ProgressBar
@onready var _device_label: Label = $VBox/DeviceRow/DeviceLabel
@onready var _status_label: Label = $VBox/DeviceRow/StatusLabel
@onready var _reconnect_bar: ProgressBar = $VBox/ReconnectBar

## How fast the meter falls when audio stops (higher = faster decay)
@export var decay_speed: float = 8.0

## Minimum level to show (prevents flickering at silence)
@export var noise_floor: float = 0.001

var _current_level: float = 0.0


func _ready() -> void:
	SignalBus.audio_level.connect(_on_audio_level)
	SignalBus.mic_stopped.connect(_on_mic_stopped)
	SignalBus.mic_device_disconnected.connect(_on_mic_disconnected)
	SignalBus.mic_device_reconnected.connect(_on_mic_reconnected)
	SignalBus.mic_reconnect_progress.connect(_on_reconnect_progress)
	SignalBus.mic_state_changed.connect(_on_state_changed)

	_reconnect_bar.visible = false
	_update_status_label("IDLE")
	_refresh_device_label()



func _process(delta: float) -> void:
	if _current_level > 0.0:
		_current_level = maxf(0.0, _current_level - decay_speed * delta)
	_progress_bar.value = _current_level * 100.0
	_update_bar_color(_current_level)


## Called by SignalBus when main.gd emits RMS level.
func _on_audio_level(rms: float) -> void:
	_current_level = maxf(rms, noise_floor)


## Reset on mic stop.
func _on_mic_stopped() -> void:
	reset()


func _on_mic_disconnected(device_id: String) -> void:
	_device_label.text = "Device: " + device_id
	_update_status_label("DISCONNECTED")
	_reconnect_bar.visible = true
	_reconnect_bar.value = 0.0


func _on_mic_reconnected(device_id: String) -> void:
	_device_label.text = "Device: " + device_id
	_update_status_label("ACTIVE")
	_reconnect_bar.visible = false
	_reconnect_bar.value = 0.0


func _on_reconnect_progress(percent: float) -> void:
	_reconnect_bar.value = percent


func _on_state_changed(new_state: String) -> void:
	_update_status_label(new_state)
	if new_state != "RECONNECTING":
		_reconnect_bar.visible = false
		_reconnect_bar.value = 0.0
	else:
		_reconnect_bar.visible = true


## Public reset — also callable from main.gd.
func reset() -> void:
	_current_level = 0.0
	_progress_bar.value = 0.0


func _refresh_device_label() -> void:
	if has_node("/root/MicManager"):
		var device: String = MicManager.get_current_device()
		if device.is_empty():
			device = "Default"
		_device_label.text = "Device: " + device
	else:
		_device_label.text = "Device: Default"


func _update_status_label(state: String) -> void:
	match state:
		"ACTIVE":
			_status_label.text = "● CONNECTED"
			_status_label.modulate = Color(0.0, 1.0, 0.0)
		"DISCONNECTED":
			_status_label.text = "● DISCONNECTED"
			_status_label.modulate = Color(1.0, 0.3, 0.3)
		"RECONNECTING":
			_status_label.text = "⟳ RECONNECTING"
			_status_label.modulate = Color(1.0, 0.8, 0.0)
		_:
			_status_label.text = "● IDLE"
			_status_label.modulate = Color(0.6, 0.6, 0.6)


func _update_bar_color(level: float) -> void:
	if level < 0.3:
		_progress_bar.modulate = Color(0.0, 1.0, 0.0)
	elif level < 0.7:
		_progress_bar.modulate = Color(1.0, 1.0, 0.0)
	else:
		_progress_bar.modulate = Color(1.0, 0.0, 0.0)

