## push_to_talk_button.gd
## Reusable UI component for push-to-talk / hotword toggle mode.
##
## Displays the current PTT mode (Hold / Toggle), an activation button,
## and a listening-state indicator. Coordinates with CommandDispatcher for
## press/release and mode switching, persisting preferences via ConfigManager.
##
## task-13: Hotword and push-to-talk toggle mode (hold vs tap-to-toggle)
extends Control

@onready var _mode_label: Label = $VBox/TopRow/ModeLabel
@onready var _state_label: Label = $VBox/StateLabel
@onready var _ptt_button: Button = $VBox/PTTButton
@onready var _toggle_mode_button: Button = $VBox/TopRow/ToggleModeButton
@onready var _hotword_label: Label = $VBox/HotwordLabel


func _ready() -> void:
	_ptt_button.button_down.connect(_on_ptt_button_down)
	_ptt_button.button_up.connect(_on_ptt_button_up)
	_ptt_button.pressed.connect(_on_ptt_pressed)
	_toggle_mode_button.pressed.connect(_on_toggle_mode_pressed)

	SignalBus.push_to_talk_toggled.connect(_on_ptt_toggled)
	SignalBus.config_changed.connect(_on_config_changed)

	_refresh_mode_label()
	_refresh_hotword_label()
	_refresh_state_label(false)


## Refresh UI to reflect current mode from CommandDispatcher.
func _refresh_mode_label() -> void:
	var mode: String = CommandDispatcher.get_ptt_mode()
	if mode == "toggle":
		_mode_label.text = "Mode: Toggle"
		_ptt_button.tooltip_text = "Click to start listening; click again to stop"
	else:
		_mode_label.text = "Mode: Hold"
		_ptt_button.tooltip_text = "Hold to listen; release to stop"


func _refresh_hotword_label() -> void:
	var hw_enabled: bool = ConfigManager.get_hotword_enabled()
	_hotword_label.text = "Hotword: %s" % ("On" if hw_enabled else "Off (stub)")
	_hotword_label.modulate = Color(0.0, 1.0, 0.5) if hw_enabled else Color(0.6, 0.6, 0.6)


func _refresh_state_label(active: bool) -> void:
	if active:
		_state_label.text = "🎤 Listening…"
		_state_label.modulate = Color(0.0, 1.0, 0.0)
		_ptt_button.text = "Listening"
	else:
		_state_label.text = "● Idle"
		_state_label.modulate = Color(0.6, 0.6, 0.6)
		_ptt_button.text = "Push to Talk"


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_ptt_button_down() -> void:
	if CommandDispatcher.get_ptt_mode() == "hold":
		CommandDispatcher.ptt_press()


func _on_ptt_button_up() -> void:
	if CommandDispatcher.get_ptt_mode() == "hold":
		CommandDispatcher.ptt_release()


func _on_ptt_pressed() -> void:
	if CommandDispatcher.get_ptt_mode() == "toggle":
		if CommandDispatcher.is_ptt_active():
			CommandDispatcher.ptt_release()
		else:
			CommandDispatcher.ptt_press()


func _on_toggle_mode_pressed() -> void:
	var current_mode: String = CommandDispatcher.get_ptt_mode()
	var new_mode: String = "toggle" if current_mode == "hold" else "hold"
	CommandDispatcher.set_ptt_mode(new_mode)
	_refresh_mode_label()


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_ptt_toggled(active: bool) -> void:
	_refresh_state_label(active)


func _on_config_changed(key: String, _value: Variant) -> void:
	if key == "ptt.mode":
		_refresh_mode_label()
	elif key == "ptt.hotword_enabled":
		_refresh_hotword_label()
