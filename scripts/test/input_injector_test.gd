## input_injector_test.gd
## Manual test scene for the InputInjector GDExtension class.
## Requires the os_control GDExtension to be built and loaded.
extends Control

## Use the safe ClassDB.instantiate path so the scene loads even without the extension.
var _injector: Object = null

@onready var output_label: Label = $VBox/OutputLabel


func _ready() -> void:
	if ClassDB.class_exists("InputInjector"):
		_injector = ClassDB.instantiate("InputInjector")
	else:
		output_label.text = "⚠ InputInjector GDExtension not loaded"

	$VBox/TypeTextButton.pressed.connect(_on_type_text)
	$VBox/PressCtrlCButton.pressed.connect(_on_press_ctrl_c)
	$VBox/MoveMouseButton.pressed.connect(_on_move_mouse)
	$VBox/ClickLeftButton.pressed.connect(_on_click_left)


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
