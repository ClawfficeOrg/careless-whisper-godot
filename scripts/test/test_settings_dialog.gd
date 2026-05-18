## test_settings_dialog.gd
## Manual test harness for the expanded settings dialog.
## Opens the ConfigDialog and exercises theme, startup, and hotkey tabs.
extends Control

@onready var _open_button: Button    = $VBox/OpenButton
@onready var _status_label: Label    = $VBox/StatusLabel
@onready var _theme_label: Label     = $VBox/ThemeLabel
@onready var _startup_label: Label   = $VBox/StartupLabel
@onready var _hotkey_label: Label    = $VBox/HotkeyLabel

var _dialog: Window = null


func _ready() -> void:
	_open_button.pressed.connect(_on_open_dialog)
	SignalBus.config_changed.connect(_on_config_changed)
	SignalBus.theme_changed.connect(_on_theme_changed)
	_refresh_labels()


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_open_dialog() -> void:
	if _dialog == null:
		var packed: PackedScene = load("res://scenes/ui/config_dialog.tscn")
		_dialog = packed.instantiate()
		add_child(_dialog)
	_dialog.popup_centered()
	_status_label.text = "Dialog opened."


func _on_config_changed(key: String, value: Variant) -> void:
	_status_label.text = "Config changed: %s = %s" % [key, str(value)]
	_refresh_labels()


func _on_theme_changed(theme_id: String) -> void:
	_theme_label.text = "Theme signal: %s" % theme_id


func _refresh_labels() -> void:
	_theme_label.text = "ui.theme = %s" % ConfigManager.get_theme_id()
	_startup_label.text = (
		"startup.launch_on_boot = %s  |  mode = %s"
		% [ConfigManager.get_startup_enabled(), ConfigManager.get_startup_mode()]
	)
	_hotkey_label.text = "PTT insert = %s" % ConfigManager.get_hotkey("mode.ptt_key_insert")
