## model_browser.gd
## UI component for browsing, downloading, and managing whisper models.
## Shows per-model size, loaded indicator, and prompts for delete confirmation.
## Designed to be embedded as the "Models" tab in the config dialog.
extends VBoxContainer

const ITEM_SCENE: PackedScene = preload("res://scenes/ui/model_item.tscn")

# ---------------------------------------------------------------------------
# UI References
# ---------------------------------------------------------------------------
@onready var _model_list_box: VBoxContainer = $ScrollContainer/ModelListBox
@onready var _download_button: Button = $ButtonRow/DownloadButton
@onready var _load_button: Button = $ButtonRow/LoadButton
@onready var _browse_button: Button = $BrowseRow/BrowseButton
@onready var _description_label: Label = $DescriptionLabel
@onready var _progress_bar: ProgressBar = $ProgressBar
@onready var _delete_confirm: ConfirmationDialog = $DeleteConfirmDialog

## Emitted when a model is selected and should be loaded by the parent scene.
signal load_model_requested(model_path: String)

## Whisper node reference (injected from ConfigDialog).
var _whisper: Node = null

## Currently selected model name.
var _selected_model: String = ""

## Model name awaiting delete confirmation.
var _pending_delete: String = ""


func _ready() -> void:
	_download_button.pressed.connect(_on_download_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_browse_button.pressed.connect(_on_browse_pressed)
	_delete_confirm.confirmed.connect(_on_delete_confirmed)

	ModelManager.download_started.connect(_on_download_started)
	ModelManager.download_progress.connect(_on_download_progress)
	ModelManager.download_completed.connect(_on_download_completed)
	ModelManager.download_failed.connect(_on_download_failed)
	ModelManager.model_deleted.connect(_on_model_deleted)
	ModelManager.model_list_updated.connect(_on_model_list_updated)

	SignalBus.model_ready.connect(_on_signal_bus_model_ready)

	_refresh_model_list()


func set_whisper_node(node: Node) -> void:
	_whisper = node


# ---------------------------------------------------------------------------
# Public
# ---------------------------------------------------------------------------

func refresh() -> void:
	_refresh_model_list()


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _refresh_model_list() -> void:
	for child in _model_list_box.get_children():
		child.queue_free()

	for model_name in ModelManager.get_available_models():
		var is_local: bool = ModelManager.is_model_downloaded(model_name)
		var size_bytes: int = ModelManager.get_model_size(model_name)
		var is_loaded: bool = ModelManager.is_model_loaded(model_name)

		var item: Node = ITEM_SCENE.instantiate()
		_model_list_box.add_child(item)
		item.setup(model_name, size_bytes, is_loaded, is_local)
		item.selected.connect(_on_item_selected)
		item.delete_requested.connect(_on_item_delete_requested)

	_update_button_states()


func _update_button_states() -> void:
	if _selected_model.is_empty():
		_download_button.disabled = true
		_load_button.disabled = true
		_description_label.text = "Select a model"
		return

	var info: Dictionary = ModelManager.get_model_info(_selected_model)
	var is_local: bool = ModelManager.is_model_downloaded(_selected_model)

	_description_label.text = info.get("description", "No description")
	_download_button.disabled = is_local
	_load_button.disabled = not is_local or _whisper == null


func _find_item_for_model(model_name: String) -> Node:
	for child in _model_list_box.get_children():
		if child.has_method("set_loaded") and child.get("_model_name") == model_name:
			return child
	return null


# ---------------------------------------------------------------------------
# Handlers — model item signals
# ---------------------------------------------------------------------------

func _on_item_selected(model_name: String) -> void:
	_selected_model = model_name
	_update_button_states()


func _on_item_delete_requested(model_name: String) -> void:
	if ModelManager.is_model_loaded(model_name):
		_description_label.text = (
			"Cannot delete '%s' — it is currently loaded." % model_name
		)
		return

	_pending_delete = model_name
	_delete_confirm.title = "Delete Model"
	_delete_confirm.dialog_text = (
		"Delete '%s'?\nThis cannot be undone." % model_name
	)
	_delete_confirm.popup_centered()


# ---------------------------------------------------------------------------
# Handlers — button / dialog
# ---------------------------------------------------------------------------

func _on_delete_confirmed() -> void:
	if _pending_delete.is_empty():
		return
	ModelManager.delete_model(_pending_delete)
	if _selected_model == _pending_delete:
		_selected_model = ""
	_pending_delete = ""


func _on_download_pressed() -> void:
	if _selected_model.is_empty():
		return

	ModelManager.download_model(_selected_model)
	_download_button.disabled = true
	_download_button.text = "Downloading…"
	_progress_bar.show()
	_progress_bar.value = 0.0


func _on_load_pressed() -> void:
	if _selected_model.is_empty() or _whisper == null:
		return

	var path := ModelManager.get_model_path(_selected_model)
	if path.is_empty():
		return

	ConfigManager.set_value("whisper.model", _selected_model)
	ConfigManager.set_value("whisper.model_path", path)
	load_model_requested.emit(path)


func _on_browse_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.bin ; GGML model files"])
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	# Pre-navigate to user://models if it exists, otherwise project models dir
	var user_models: String = ProjectSettings.globalize_path("user://models")
	if DirAccess.open("user://models") != null:
		dialog.current_dir = user_models
	elif DirAccess.open("res://models") != null:
		dialog.current_dir = ProjectSettings.globalize_path("res://models")
	dialog.file_selected.connect(func(path: String) -> void:
		load_model_requested.emit(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))


# ---------------------------------------------------------------------------
# Handlers — ModelManager signals
# ---------------------------------------------------------------------------

func _on_download_started(model_name: String) -> void:
	if model_name != _selected_model:
		return
	_progress_bar.show()
	_progress_bar.value = 0.0


func _on_download_progress(model_name: String, progress: float) -> void:
	if model_name != _selected_model:
		return
	_progress_bar.value = progress * 100.0


func _on_download_completed(model_name: String, _path: String) -> void:
	_download_button.text = "Download"
	if model_name == _selected_model:
		_progress_bar.hide()
	_refresh_model_list()
	# Re-select the just-downloaded model.
	for child in _model_list_box.get_children():
		if child.get("_model_name") == model_name:
			_on_item_selected(model_name)
			break


func _on_download_failed(model_name: String, _error: String) -> void:
	if model_name != _selected_model:
		return
	_progress_bar.hide()
	_download_button.text = "Download"
	_download_button.disabled = false


func _on_model_deleted(_model_name: String) -> void:
	_refresh_model_list()


func _on_model_list_updated() -> void:
	_refresh_model_list()


# ---------------------------------------------------------------------------
# Handlers — SignalBus
# ---------------------------------------------------------------------------

func _on_signal_bus_model_ready(_model_name: String) -> void:
	_refresh_model_list()
