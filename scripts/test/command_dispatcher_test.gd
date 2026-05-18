## command_dispatcher_test.gd
## Manual test scene for CommandDispatcher (task-7).
## Buttons simulate transcription phrases and show matched commands/signals.
extends Control

@onready var _result_label: Label = $VBox/ResultLabel
@onready var _input: LineEdit = $VBox/TranscriptInput


func _ready() -> void:
	CommandDispatcher.command_executed.connect(_on_command_executed)
	CommandDispatcher.macro_triggered.connect(_on_macro_triggered)
	CommandDispatcher.window_command.connect(_on_window_command)
	$VBox/DispatchButton.pressed.connect(_on_dispatch)
	$VBox/MacroButton.pressed.connect(_on_test_macro)
	$VBox/FocusSideButton.pressed.connect(_on_test_focus_side)
	$VBox/FocusButton.pressed.connect(_on_test_focus)
	$VBox/CloseButton.pressed.connect(_on_test_close)
	$VBox/MovePixelsButton.pressed.connect(_on_test_move_pixels)
	$VBox/MoveSideButton.pressed.connect(_on_test_move_side)
	$VBox/TypeButton.pressed.connect(_on_test_type)
	$VBox/PressButton.pressed.connect(_on_test_press)


func _on_command_executed(command_name: String, args: Dictionary) -> void:
	_result_label.text = "✓ command_executed: %s %s" % [command_name, args]


func _on_macro_triggered(macro_id: String, context: Dictionary) -> void:
	var phrase: String = context.get("phrase", "")
	_result_label.text = (
		"✓ macro_triggered: %s (phrase: \"%s\")" % [macro_id, phrase]
	)


func _on_window_command(action: String, target: String, params: Dictionary) -> void:
	_result_label.text = "✓ window_command: %s %s %s" % [action, target, params]


func _on_dispatch() -> void:
	var text: String = _input.text.strip_edges()
	if text.is_empty():
		_result_label.text = "⚠ Enter a transcript phrase first"
		return
	_result_label.text = "✗ No pattern matched: \"%s\"" % text
	CommandDispatcher.receive_transcript(text)


func _on_test_macro() -> void:
	_result_label.text = "Firing: run macro open_calculator…"
	CommandDispatcher.receive_transcript("run macro open_calculator")


func _on_test_focus_side() -> void:
	_result_label.text = "Firing: focus terminal on left…"
	CommandDispatcher.receive_transcript("focus terminal on left")


func _on_test_focus() -> void:
	_result_label.text = "Firing: focus firefox…"
	CommandDispatcher.receive_transcript("focus firefox")


func _on_test_close() -> void:
	_result_label.text = "Firing: close browser…"
	CommandDispatcher.receive_transcript("close browser")


func _on_test_move_pixels() -> void:
	_result_label.text = "Firing: move window three pixels right…"
	CommandDispatcher.receive_transcript("move window three pixels right")


func _on_test_move_side() -> void:
	_result_label.text = "Firing: move window to the left…"
	CommandDispatcher.receive_transcript("move window to the left")


func _on_test_type() -> void:
	_result_label.text = "Firing: type hello world…"
	CommandDispatcher.receive_transcript("type hello world")


func _on_test_press() -> void:
	_result_label.text = "Firing: press escape…"
	CommandDispatcher.receive_transcript("press escape")
