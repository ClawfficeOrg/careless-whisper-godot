## mic_level_meter.gd
## Visualizes microphone input level in real-time.
## Add as a child of the main UI and call update_level(rms) from _process.
extends Range

## How fast the meter falls when audio stops (higher = slower decay)
@export var decay_speed: float = 8.0

## Minimum level to show (prevents flickering at silence)
@export var noise_floor: float = 0.001

## Peak hold time in seconds
@export var peak_hold_time: float = 1.5

var _peak_value: float = 0.0
var _peak_timer: float = 0.0

@onready var _style_box: StyleBoxFlat = StyleBoxFlat.new()


func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	value = 0.0
	# Configure as a horizontal progress bar
	custom_minimum_size = Vector2(200, 8)
	_style_box.bg_color = Color.GREEN
	_style_box.corner_radius_top_left = 2
	_style_box.corner_radius_top_right = 2
	_style_box.corner_radius_bottom_left = 2
	_style_box.corner_radius_bottom_right = 2
	add_theme_stylebox_override("fill", _style_box)


func _process(delta: float) -> void:
	# Decay the meter when not receiving updates
	if value > 0.0:
		value = maxf(0.0, value - decay_speed * delta)

	# Update peak hold timer
	if _peak_timer > 0.0:
		_peak_timer -= delta
		if _peak_timer <= 0.0:
			_peak_value = 0.0

	_update_color()


## Call this every frame while recording to update the meter.
## rms should be a value between 0.0 (silence) and 1.0 (max).
func update_level(rms: float) -> void:
	# Apply noise floor
	var level := maxf(rms, noise_floor)
	value = level

	# Track peak
	if level > _peak_value:
		_peak_value = level
		_peak_timer = peak_hold_time


## Reset the meter to zero.
func reset() -> void:
	value = 0.0
	_peak_value = 0.0
	_peak_timer = 0.0


func _update_color() -> void:
	# Color gradient: green -> yellow -> red based on level
	var level := value as float
	var color: Color
	if level < 0.5:
		color = Color.GREEN.lerp(Color.YELLOW, level * 2.0)
	elif level < 0.8:
		color = Color.YELLOW.lerp(Color.ORANGE, (level - 0.5) * 3.33)
	else:
		color = Color.ORANGE.lerp(Color.RED, (level - 0.8) * 5.0)

	_style_box.bg_color = color
