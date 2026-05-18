## push_to_talk_test.gd
## Manual test scene for task-13: Hotword and push-to-talk toggle mode.
##
## Exercises hold vs toggle mode, simulates InputMap action events, and
## tests the hotword stub trigger. Observe the log area and PushToTalkButton
## indicators to verify correct behaviour.
##
## Run in editor: open scenes/test/push_to_talk_test.tscn and press F5.
extends Control

@onready var _status_label: Label = $VBox/StatusLabel
@onready var _log_label: Label = $VBox/LogLabel
@onready var _mode_row_label: Label = $VBox/InfoRow/ModeRowLabel
@onready var _active_row_label: Label = $VBox/InfoRow/ActiveRowLabel

var _log_lines: Array[String] = []
const MAX_LOG_LINES: int = 12


func _ready() -> void:
	$VBox/ButtonRow/SimPressBtn.pressed.connect(_on_sim_press)
	$VBox/ButtonRow/SimReleaseBtn.pressed.connect(_on_sim_release)
	$VBox/ButtonRow/SimHotwordBtn.pressed.connect(_on_sim_hotword)
	$VBox/ButtonRow/SetHoldBtn.pressed.connect(_on_set_hold)
	$VBox/ButtonRow/SetToggleBtn.pressed.connect(_on_set_toggle)
	$VBox/ButtonRow/ToggleHotwordBtn.pressed.connect(_on_toggle_hotword)

	CommandDispatcher.push_to_talk_pressed.connect(_on_ptt_pressed)
	CommandDispatcher.push_to_talk_released.connect(_on_ptt_released)
	CommandDispatcher.push_to_talk_toggled.connect(_on_ptt_toggled)
	CommandDispatcher.hotword_detected.connect(_on_hotword_detected)

	_status_label.text = "✓ CommandDispatcher connected"
	_log("Test scene ready. Mode: %s" % CommandDispatcher.get_ptt_mode())
	_refresh_info()


func _refresh_info() -> void:
	_mode_row_label.text = "PTT Mode: %s" % CommandDispatcher.get_ptt_mode()
	var hw: String = "On" if ConfigManager.get_hotword_enabled() else "Off (stub)"
	_active_row_label.text = (
		"Active: %s  |  Hotword: %s"
		% [str(CommandDispatcher.is_ptt_active()), hw]
	)


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_sim_press() -> void:
	_log("→ Simulating ptt_press()")
	CommandDispatcher.ptt_press()
	_refresh_info()


func _on_sim_release() -> void:
	_log("→ Simulating ptt_release()")
	CommandDispatcher.ptt_release()
	_refresh_info()


func _on_sim_hotword() -> void:
	_log("→ Simulating hotword detection")
	CommandDispatcher.simulate_hotword()
	_refresh_info()


func _on_set_hold() -> void:
	_log("→ Setting mode to: hold")
	CommandDispatcher.set_ptt_mode("hold")
	_refresh_info()


func _on_set_toggle() -> void:
	_log("→ Setting mode to: toggle")
	CommandDispatcher.set_ptt_mode("toggle")
	_refresh_info()


func _on_toggle_hotword() -> void:
	var new_val: bool = not ConfigManager.get_hotword_enabled()
	ConfigManager.set_hotword_enabled(new_val)
	_log("→ Hotword enabled: %s" % str(new_val))
	_refresh_info()


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_ptt_pressed() -> void:
	_log("✓ push_to_talk_pressed fired")
	_refresh_info()


func _on_ptt_released() -> void:
	_log("✓ push_to_talk_released fired")
	_refresh_info()


func _on_ptt_toggled(active: bool) -> void:
	_log("✓ push_to_talk_toggled: %s" % str(active))
	_refresh_info()


func _on_hotword_detected() -> void:
	_log("✓ hotword_detected fired")
	_refresh_info()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines = _log_lines.slice(_log_lines.size() - MAX_LOG_LINES)
	_log_label.text = "\n".join(_log_lines)
