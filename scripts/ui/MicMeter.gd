extends Control

@onready var progress_bar: ProgressBar = $ProgressBar

func _ready():
    set_process(true)

func _process(delta: float) -> void:
    var level = get_input_level()
    progress_bar.value = level * 100
    update_bar_color(level)

func get_input_level() -> float:
    # Placeholder: Replace with actual AudioServer RMS level calculation
    return randf()

func update_bar_color(level: float) -> void:
    if level < 0.3:
        progress_bar.modulate = Color(0, 1, 0)  # Green
    elif level < 0.7:
        progress_bar.modulate = Color(1, 1, 0)  # Yellow
    else:
        progress_bar.modulate = Color(1, 0, 0)  # Red