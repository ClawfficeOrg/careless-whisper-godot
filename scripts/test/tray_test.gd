## tray_test.gd
## Manual test scene for the TrayManager autoload.
##
## Verification steps:
## 1. Run the scene — status label shows whether TrayManager autoload is present.
## 2. "Native tray:" label shows whether the SystemTray GDExtension was loaded.
## 3. "Show / Hide" buttons call show_tray() / hide_tray() — verify in OS tray area.
## 4. "Simulate" buttons emit tray_menu_selected locally and verify the last-event
##    label updates accordingly.
## 5. When native tray is available, right-click the tray icon and select "Open",
##    "Settings…", and "Quit" — verify each is logged in the last-event label and
##    that "Quit" terminates the app.
##
## Windows: compiled os_control DLL required; icon should appear in the taskbar
##          notification area (bottom-right).
## Linux X11: libappindicator or xembed required; icon appears in the system panel.
## Linux Wayland: tray support may be absent — expect "not available" fallback.
extends Control

@onready var _status_label: Label = $VBox/StatusLabel
@onready var _available_label: Label = $VBox/AvailableLabel
@onready var _last_event_label: Label = $VBox/LastEventLabel


func _ready() -> void:
	if has_node("/root/TrayManager"):
		_status_label.text = "✓ TrayManager autoload present"
		TrayManager.tray_menu_selected.connect(_on_tray_menu_selected)
		TrayManager.tray_icon_activated.connect(_on_tray_icon_activated)
		var available: String = "yes" if TrayManager.is_available() else "no (placeholder mode)"
		_available_label.text = "Native tray: " + available
	else:
		_status_label.text = "✗ TrayManager autoload NOT registered"
		_available_label.text = "Native tray: N/A"

	$VBox/ShowBtn.pressed.connect(_on_show_btn_pressed)
	$VBox/HideBtn.pressed.connect(_on_hide_btn_pressed)
	$VBox/OpenMenuBtn.pressed.connect(_on_simulate_open)
	$VBox/SettingsMenuBtn.pressed.connect(_on_simulate_settings)


func _on_show_btn_pressed() -> void:
	if not has_node("/root/TrayManager"):
		_last_event_label.text = "✗ TrayManager not available"
		return
	TrayManager.show_tray()
	_last_event_label.text = "Called show_tray()"


func _on_hide_btn_pressed() -> void:
	if not has_node("/root/TrayManager"):
		_last_event_label.text = "✗ TrayManager not available"
		return
	TrayManager.hide_tray()
	_last_event_label.text = "Called hide_tray()"


func _on_simulate_open() -> void:
	_on_tray_menu_selected("open")


func _on_simulate_settings() -> void:
	_on_tray_menu_selected("settings")


func _on_tray_menu_selected(item_id: String) -> void:
	_last_event_label.text = "tray_menu_selected: " + item_id


func _on_tray_icon_activated() -> void:
	_last_event_label.text = "tray_icon_activated (left-click)"
