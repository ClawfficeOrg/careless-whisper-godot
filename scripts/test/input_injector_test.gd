extends Control

onready var injector := preload("res://addons/os_control/src/input_injector.gdns").new()
onready var output_label := $VBox/OutputLabel

func _ready():
	$VBox/TypeTextButton.pressed.connect(_on_type_text)
	$VBox/PressCtrlCButton.pressed.connect(_on_press_ctrl_c)
	$VBox/MoveMouseButton.pressed.connect(_on_move_mouse)
	$VBox/ClickLeftButton.pressed.connect(_on_click_left)

func _on_type_text():
	var ok = injector.type_text("Hello from test")
	output_label.text = "Type text: %s" % ok

func _on_press_ctrl_c():
	var ok = injector.press_key("ctrl+c")
	output_label.text = "Press Ctrl+C: %s" % ok

func _on_move_mouse():
	var ok = injector.move_mouse(100, 100)
	output_label.text = "Move mouse: %s" % ok

func _on_click_left():
	var ok = injector.click_mouse("left")
	output_label.text = "Left click: %s" % ok
