## model_browser.gd
## UI component for browsing, downloading, and managing whisper models.
## Add this as a tab in the config dialog.
extends VBoxContainer

# ---------------------------------------------------------------------------
# UI References
# ---------------------------------------------------------------------------
@onready var model_list: ItemList = $ModelList
@onready var download_button: Button = $ButtonRow/DownloadButton
@onready var delete_button: Button = $ButtonRow/DeleteButton
@onready var load_button: Button = $ButtonRow/LoadButton
@onready var description_label: Label = $DescriptionLabel
@onready var progress_bar: ProgressBar = $ProgressBar

## Emitted when a model is selected and should be loaded
signal load_model_requested(model_path: String)

## Whisper node reference (injected)
var _whisper: Node = null

## Currently selected model name
var _selected_model: String = ""


func _ready() -> void:
	_connect_signals()
	_refresh_model_list()


func set_whisper_node(node: Node) -> void:
	_whisper = node


# ---------------------------------------------------------------------------
# Public
# ---------------------------------------------------------------------------

func refresh() -> void:
	_refresh_model_list()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	model_list.item_selected.connect(_on_model_selected)
	download_button.pressed.connect(_on_download_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	load_button.pressed.connect(_on_load_pressed)

	ModelManager.download_started.connect(_on_download_started)
	ModelManager.download_progress.connect(_on_download_progress)
	ModelManager.download_completed.connect(_on_download_completed)
	ModelManager.download_failed.connect(_on_download_failed)


func _refresh_model_list() -> void:
	model_list.clear()
	var local_models := ModelManager.get_local_models()

	# Add all available models
	for model_name in ModelManager.get_available_models():
		var info: Dictionary = ModelManager.get_model_info(model_name)
		var is_local := model_name in local_models

		var display := model_name
		if is_local:
			display = "✓ %s" % model_name
		else:
			display = "  %s (%d MB)" % [model_name, info.get("size_mb", 0)]

		model_list.add_item(display)
		model_list.set_item_metadata(model_list.item_count - 1, model_name)

		# Gray out non-downloaded models slightly
		if not is_local:
			model_list.set_item_custom_fg_color(model_list.item_count - 1, Color.GRAY)

	_update_button_states()


func _update_button_states() -> void:
	if _selected_model.is_empty():
		download_button.disabled = true
		delete_button.disabled = true
		load_button.disabled = true
		description_label.text = "Select a model"
		return

	var info: Dictionary = ModelManager.get_model_info(_selected_model)
	var is_local := ModelManager.is_model_downloaded(_selected_model)

	description_label.text = info.get("description", "No description")
	download_button.disabled = is_local
	delete_button.disabled = not is_local
	load_button.disabled = not is_local or _whisper == null


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_model_selected(index: int) -> void:
	_selected_model = model_list.get_item_metadata(index)
	_update_button_states()


func _on_download_pressed() -> void:
	if _selected_model.is_empty():
		return

	ModelManager.download_model(_selected_model)
	download_button.disabled = true
	download_button.text = "Downloading…"
	progress_bar.show()
	progress_bar.value = 0.0


func _on_delete_pressed() -> void:
	if _selected_model.is_empty():
		return

	var confirmed := await _show_confirm_dialog(
		"Delete Model",
		"Delete %s? This cannot be undone." % _selected_model
	)

	if confirmed:
		ModelManager.delete_model(_selected_model)
		_refresh_model_list()
		_selected_model = ""


func _on_load_pressed() -> void:
	if _selected_model.is_empty() or _whisper == null:
		return

	var path := ModelManager.get_model_path(_selected_model)
	if path.is_empty():
		return

	# Update config
	ConfigManager.set_value("whisper.model", _selected_model)
	ConfigManager.set_value("whisper.model_path", path)

	# Emit signal for config dialog to handle
	load_model_requested.emit(path)


func _on_download_started(model_name: String) -> void:
	if model_name != _selected_model:
		return
	progress_bar.show()
	progress_bar.value = 0.0


func _on_download_progress(model_name: String, progress: float) -> void:
	if model_name != _selected_model:
		return
	progress_bar.value = progress * 100.0


func _on_download_completed(model_name: String, _path: String) -> void:
	if model_name != _selected_model:
		_refresh_model_list()
		return

	progress_bar.hide()
	download_button.text = "Download"
	_refresh_model_list()

	# Auto-select the newly downloaded model
	for i in model_list.item_count:
		if model_list.get_item_metadata(i) == model_name:
			model_list.select(i)
			_on_model_selected(i)
			break


func _on_download_failed(model_name: String, _error: String) -> void:
	if model_name != _selected_model:
		return

	progress_bar.hide()
	download_button.text = "Download"
	download_button.disabled = false


func _show_confirm_dialog(title: String, message: String) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.title = title
	add_child(dialog)
	dialog.popup_centered()
	var result: bool = await dialog.confirmed
	dialog.queue_free()
	return result
