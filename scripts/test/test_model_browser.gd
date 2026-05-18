## test_model_browser.gd
## Manual test scene for the ModelBrowser model-management UI.
##
## Test cases:
##   a) Sizes shown — verify labels display actual file sizes for local models
##      and estimated "~X MB" for non-local models.
##   b) Loaded indicator — toggle active model and confirm the green "●" updates.
##   c) Delete unloaded model — confirm dialog fires → file removed →
##      model_list_updated emitted → row disappears.
##   d) Delete loaded model — UI blocks deletion and shows warning in description.
##
## Run in editor: open scenes/test/model_browser_test.tscn and press F5.
extends Control

@onready var _browser: VBoxContainer = $VBox/ModelBrowser
@onready var _status_label: Label = $VBox/StatusLabel
@onready var _model_name_edit: LineEdit = $VBox/ControlRow/ModelNameEdit
@onready var _set_loaded_btn: Button = $VBox/ControlRow/SetLoadedBtn
@onready var _refresh_btn: Button = $VBox/ControlRow/RefreshBtn


func _ready() -> void:
	_set_loaded_btn.pressed.connect(_on_set_loaded_pressed)
	_refresh_btn.pressed.connect(_on_refresh_pressed)

	ModelManager.model_deleted.connect(_on_model_deleted)
	ModelManager.model_list_updated.connect(_on_model_list_updated)
	SignalBus.model_ready.connect(_on_model_ready)

	_status_label.text = (
		"Ready — use controls below to exercise the ModelBrowser.\n"
		+ "Steps:\n"
		+ "  a) Check size labels: local=actual bytes, non-local=~X MB\n"
		+ "  b) Type a model name, press Set Loaded, verify ● appears\n"
		+ "  c) Click Delete on a non-loaded model, confirm dialog, row gone\n"
		+ "  d) Load a model first, then try Delete — should show warning"
	)


func _on_set_loaded_pressed() -> void:
	var model_name: String = _model_name_edit.text.strip_edges()
	if model_name.is_empty():
		_status_label.text = "Enter a model name first."
		return
	ConfigManager.set_value("whisper.model", model_name)
	_browser.refresh()
	_status_label.text = "Set loaded model to '%s' — check ● indicator." % model_name


func _on_refresh_pressed() -> void:
	_browser.refresh()
	_status_label.text = "List refreshed."


func _on_model_deleted(model_name: String) -> void:
	_status_label.text = "✓ model_deleted fired for '%s'" % model_name


func _on_model_list_updated() -> void:
	_status_label.text = "✓ model_list_updated fired"


func _on_model_ready(model_name: String) -> void:
	_status_label.text = "✓ model_ready fired for '%s'" % model_name
