## loading_overlay.gd
## Semi-transparent overlay with a spinner and message.
## Shows during long operations like model loading.
extends Control

@onready var label: Label = $PanelContainer/VBox/Label
@onready var progress: ProgressBar = $PanelContainer/VBox/ProgressBar

var _spinner_chars := ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
var _spinner_idx := 0


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if visible:
		# Animate spinner
		_spinner_idx = (_spinner_idx + 1) % _spinner_chars.size()
		var text := label.text
		if text.begins_with("["):
			var end := text.find("]")
			if end > 0:
				label.text = "[%s] %s" % [_spinner_chars[_spinner_idx], text.substr(end + 2)]


func show_loading(message: String) -> void:
	label.text = "[%s] %s" % [_spinner_chars[_spinner_idx], message]
	progress.value = 0.0
	show()


func show_progress(message: String, percent: float) -> void:
	label.text = "[%s] %s" % [_spinner_chars[_spinner_idx], message]
	progress.value = clampf(percent, 0.0, 100.0)
	if not visible:
		show()


func hide_loading() -> void:
	hide()
	progress.value = 0.0
