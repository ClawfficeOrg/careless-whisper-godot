## os_controller_test.gd
## Manual test scene for the OSController autoload.
## Verifies autoload presence and safe fallback when extension is absent.
extends Control

@onready var _status_label: Label = $VBox/StatusLabel
@onready var _window_label: Label = $VBox/WindowLabel
@onready var _result_label: Label = $VBox/ResultLabel
@onready var _window_input: LineEdit = $VBox/WindowInput


func _ready() -> void:
	if has_node("/root/OSController"):
		_status_label.text = "✓ OSController autoload present"
		OSController.focus_window_result.connect(_on_focus_result)
		OSController.command_executed.connect(_on_command_executed)
		OSController.window_changed.connect(_on_window_changed)
	else:
		_status_label.text = "✗ OSController autoload NOT registered"

	$VBox/GetWindowBtn.pressed.connect(_on_get_active_window)
	$VBox/ListWindowsBtn.pressed.connect(_on_list_windows)
	$VBox/FocusBtn.pressed.connect(_on_focus_window)
	$VBox/AnnounceBtn.pressed.connect(_on_announce_window)


func _on_get_active_window() -> void:
	if not has_node("/root/OSController"):
		_result_label.text = "✗ OSController not available"
		return
	var info: Dictionary = OSController.get_active_window()
	if info.has("error"):
		_result_label.text = "Error: " + str(info.get("error", ""))
	else:
		_result_label.text = "Active: " + str(info.get("title", "(unknown)"))


func _on_list_windows() -> void:
	if not has_node("/root/OSController"):
		_result_label.text = "✗ OSController not available"
		return
	var windows: Array = OSController.list_windows()
	_result_label.text = "Windows: %d found" % windows.size()


func _on_focus_window() -> void:
	if not has_node("/root/OSController"):
		_result_label.text = "✗ OSController not available"
		return
	var name: String = _window_input.text.strip_edges()
	if name.is_empty():
		_result_label.text = "⚠ Enter a window title first"
		return
	_result_label.text = "Focusing: " + name
	OSController.focus_window(name)


func _on_announce_window() -> void:
	if not has_node("/root/OSController"):
		_result_label.text = "✗ OSController not available"
		return
	_result_label.text = OSController.announce_active_window()


func _on_focus_result(success: bool, message: String) -> void:
	var icon: String = "✓" if success else "✗"
	_result_label.text = "%s %s" % [icon, message]


func _on_command_executed(command: String, success: bool) -> void:
	var icon: String = "✓" if success else "✗"
	_window_label.text = "Last cmd: %s %s" % [icon, command]


func _on_window_changed(window_info: Dictionary) -> void:
	var title: String = window_info.get("title", "(unknown)")
	_window_label.text = "Window: " + title
