## MicMeter.gd
## Passive mic level display — receives real RMS values via SignalBus.audio_level.
## Does NOT consume audio frames; audio capture is owned by main.gd.
extends Control

@onready var progress_bar: ProgressBar = $ProgressBar

## How fast the meter falls when audio stops (higher = faster decay)
@export var decay_speed: float = 8.0

## Minimum level to show (prevents flickering at silence)
@export var noise_floor: float = 0.001

var _current_level: float = 0.0


func _ready() -> void:
	# Listen for RMS values emitted by main.gd audio pipeline
	SignalBus.audio_level.connect(_on_audio_level)
	SignalBus.mic_stopped.connect(_on_mic_stopped)


func _process(delta: float) -> void:
	# Smooth decay when audio stops or level drops
	if _current_level > 0.0:
		_current_level = maxf(0.0, _current_level - decay_speed * delta)
	progress_bar.value = _current_level * 100.0
	_update_bar_color(_current_level)


## Called by SignalBus when main.gd emits RMS level
func _on_audio_level(rms: float) -> void:
	_current_level = maxf(rms, noise_floor)


## Reset on mic stop
func _on_mic_stopped() -> void:
	reset()


## Public reset — also callable from main.gd
func reset() -> void:
	_current_level = 0.0
	progress_bar.value = 0.0


func _update_bar_color(level: float) -> void:
	if level < 0.3:
		progress_bar.modulate = Color(0.0, 1.0, 0.0)   # green
	elif level < 0.7:
		progress_bar.modulate = Color(1.0, 1.0, 0.0)   # yellow
	else:
		progress_bar.modulate = Color(1.0, 0.0, 0.0)   # red
