## input_injector_test.gd
## Manual test scene for the InputInjector GDExtension class.
## Requires the os_control GDExtension to be built and loaded.
extends Control

## Use the safe ClassDB.instantiate path so the scene loads even without the extension.
var _injector: Object = null

@onready var output_label: Label = $VBox/OutputLabel
@onready var _window_id_input: LineEdit = $VBox/WindowId
@onready var _result_label: Label = $VBox/ResultLabel


func _ready() -> void:
	if ClassDB.class_exists("InputInjector"):
		_injector = ClassDB.instantiate("InputInjector")
	else:
		output_label.text = "⚠ InputInjector GDExtension not loaded"

	$VBox/TypeTextButton.pressed.connect(_on_type_text)
	$VBox/PressCtrlCButton.pressed.connect(_on_press_ctrl_c)
	$VBox/MoveMouseButton.pressed.connect(_on_move_mouse)
	$VBox/ClickLeftButton.pressed.connect(_on_click_left)
	$VBox/FocusBtn.pressed.connect(_on_focus_window)

	if has_node("/root/OSController"):
		OSController.focus_window_result.connect(_on_focus_result)
	else:
		_result_label.text = "⚠ OSController autoload not registered"


func _on_type_text() -> void:
	if _injector == null:
		return
	var ok: bool = _injector.type_text("Hello from test")
	output_label.text = "Type text: %s" % ok


func _on_press_ctrl_c() -> void:
	if _injector == null:
		return
	var ok: bool = _injector.press_key("ctrl+c")
	output_label.text = "Press Ctrl+C: %s" % ok


func _on_move_mouse() -> void:
	if _injector == null:
		return
	var ok: bool = _injector.move_mouse(100, 100)
	output_label.text = "Move mouse: %s" % ok


func _on_click_left() -> void:
	if _injector == null:
		return
	var ok: bool = _injector.click_mouse("left")
	output_label.text = "Left click: %s" % ok


func _on_focus_window() -> void:
	var window_name: String = _window_id_input.text.strip_edges()
	if window_name.is_empty():
		_result_label.text = "⚠ Enter a window title first"
		return
	if not has_node("/root/OSController"):
		_result_label.text = "⚠ OSController not available"
		return
	_result_label.text = "Focusing: " + window_name
	OSController.focus_window(window_name)


func _on_focus_result(success: bool, message: String) -> void:
	var icon: String = "✓" if success else "✗"
	_result_label.text = "%s %s" % [icon, message]
