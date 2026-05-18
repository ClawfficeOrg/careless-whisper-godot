## model_item.gd
## Per-row UI component for a single model entry in the model browser.
## Displays model name, disk size, loaded indicator, and a delete button.
## Emits signals when the row is selected or deletion is requested.
extends HBoxContainer

## Emitted when the user clicks anywhere on the row (outside the delete button).
signal selected(model_name: String)
## Emitted when the user presses the delete button.
signal delete_requested(model_name: String)

@onready var _name_label: Label = $NameLabel
@onready var _size_label: Label = $SizeLabel
@onready var _loaded_label: Label = $LoadedLabel
@onready var _delete_button: Button = $DeleteButton

var _model_name: String = ""


func _ready() -> void:
	_delete_button.pressed.connect(_on_delete_pressed)


## Populate the row with model data.
## size_bytes: actual file size; pass 0 to show estimated size_mb from metadata.
## is_loaded: whether this model is currently active.
## is_local: whether the model file is present on disk.
func setup(
	model_name: String,
	size_bytes: int,
	is_loaded: bool,
	is_local: bool
) -> void:
	_model_name = model_name
	_name_label.text = model_name
	_size_label.text = _size_text(model_name, size_bytes, is_local)
	_loaded_label.visible = is_loaded
	_delete_button.disabled = not is_local


## Update the loaded indicator without rebuilding the full row.
func set_loaded(loaded: bool) -> void:
	_loaded_label.visible = loaded


## Update the size label after a download completes.
func set_size_bytes(bytes: int) -> void:
	_size_label.text = _format_bytes(bytes)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			selected.emit(_model_name)


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_delete_pressed() -> void:
	delete_requested.emit(_model_name)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _size_text(model_name: String, size_bytes: int, is_local: bool) -> String:
	if is_local and size_bytes > 0:
		return _format_bytes(size_bytes)
	# Fall back to estimated size from metadata.
	var info: Dictionary = ModelManager.get_model_info(model_name)
	var est: int = info.get("size_mb", 0)
	if est > 0:
		return "~%d MB" % est
	return "—"


func _format_bytes(bytes: int) -> String:
	if bytes <= 0:
		return "—"
	if bytes < 1024:
		return "%d B" % bytes
	if bytes < 1024 * 1024:
		return "%.1f KB" % (float(bytes) / 1024.0)
	if bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (float(bytes) / (1024.0 * 1024.0))
	return "%.2f GB" % (float(bytes) / (1024.0 * 1024.0 * 1024.0))
