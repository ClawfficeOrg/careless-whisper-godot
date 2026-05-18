## macro_manager_test.gd
## Manual test scene for MacroManager.
## Buttons simulate transcription phrases and confirm macro_triggered fires.
extends Control

@onready var _status_label: Label = $VBox/StatusLabel


func _ready() -> void:
	MacroManager.macro_triggered.connect(_on_macro_triggered)
	$VBox/TriggerHelloButton.pressed.connect(_on_trigger_hello)
	$VBox/TriggerScreenshotButton.pressed.connect(_on_trigger_screenshot)
	$VBox/TriggerBrowserButton.pressed.connect(_on_trigger_browser)


func _on_macro_triggered(macro_name: String, meta: Dictionary) -> void:
	var phrase: String = meta.get("phrase", "")
	_status_label.text = "✓ macro_triggered: %s (phrase: \"%s\")" % [macro_name, phrase]


func _on_trigger_hello() -> void:
	_status_label.text = "Firing: hello computer…"
	SignalBus.transcription_completed.emit("hello computer")


func _on_trigger_screenshot() -> void:
	_status_label.text = "Firing: take screenshot…"
	SignalBus.transcription_completed.emit("take screenshot")


func _on_trigger_browser() -> void:
	_status_label.text = "Firing: open browser…"
	SignalBus.transcription_completed.emit("open browser")
