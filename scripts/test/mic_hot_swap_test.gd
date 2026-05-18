## mic_hot_swap_test.gd
## Manual test scene for MicManager mic hot-swap support.
##
## Buttons simulate device connect/disconnect to exercise the state machine
## without needing a physical mic or OS-level hot-plug event.
##
## Run in editor: open scenes/test/mic_hot_swap_test.tscn and press F5.
extends Control

@onready var _status_label: Label = $VBox/StatusLabel
@onready var _device_label: Label = $VBox/DeviceLabel
@onready var _device_list_label: Label = $VBox/DeviceListLabel
@onready var _state_label: Label = $VBox/StateLabel
@onready var _event_log: Label = $VBox/EventLog


func _ready() -> void:
	$VBox/DisconnectBtn.pressed.connect(_on_disconnect_pressed)
	$VBox/ReconnectBtn.pressed.connect(_on_reconnect_pressed)
	$VBox/PollBtn.pressed.connect(_on_poll_pressed)
	$VBox/ListDevicesBtn.pressed.connect(_on_list_devices_pressed)

	if has_node("/root/MicManager"):
		_status_label.text = "✓ MicManager autoload present"
		MicManager.mic_disconnected.connect(_on_mic_disconnected)
		MicManager.mic_reconnected.connect(_on_mic_reconnected)
		MicManager.reconnect_progress.connect(_on_reconnect_progress)
		MicManager.state_changed.connect(_on_state_changed)
		MicManager.device_list_changed.connect(_on_device_list_changed)
		_refresh_device_info()
	else:
		_status_label.text = "✗ MicManager autoload NOT registered"

	if has_node("/root/OSController"):
		OSController.device_list_changed.connect(_on_os_device_list_changed)
		OSController.default_device_changed.connect(_on_os_default_device_changed)


func _on_disconnect_pressed() -> void:
	if not has_node("/root/MicManager"):
		_log_event("✗ MicManager not available")
		return
	_log_event("→ Simulating disconnect...")
	MicManager.debug_simulate_disconnect()


func _on_reconnect_pressed() -> void:
	if not has_node("/root/MicManager"):
		_log_event("✗ MicManager not available")
		return
	_log_event("→ Simulating reconnect...")
	MicManager.debug_simulate_reconnect()


func _on_poll_pressed() -> void:
	if not has_node("/root/MicManager"):
		_log_event("✗ MicManager not available")
		return
	_log_event("→ Forcing device poll...")
	MicManager.poll_now()
	_refresh_device_info()


func _on_list_devices_pressed() -> void:
	_refresh_device_info()


func _on_mic_disconnected(device_id: String) -> void:
	_log_event("✗ mic_disconnected: " + device_id)


func _on_mic_reconnected(device_id: String) -> void:
	_log_event("✓ mic_reconnected: " + device_id)


func _on_reconnect_progress(percent: float) -> void:
	_state_label.text = "Reconnect progress: %.0f%%" % percent


func _on_state_changed(new_state: String) -> void:
	_state_label.text = "State: " + new_state
	_log_event("→ state_changed: " + new_state)


func _on_device_list_changed(devices: Array) -> void:
	_log_event("→ device_list_changed: %d device(s)" % devices.size())
	_refresh_device_info()


func _on_os_device_list_changed(devices: Array) -> void:
	_log_event("[OSController] device_list_changed: %d device(s)" % devices.size())


func _on_os_default_device_changed(device_id: String) -> void:
	_log_event("[OSController] default_device_changed: " + device_id)


func _refresh_device_info() -> void:
	if not has_node("/root/MicManager"):
		_device_label.text = "Device: MicManager not available"
		_device_list_label.text = "Devices: —"
		return

	var device: String = MicManager.get_current_device()
	if device.is_empty():
		device = "(none)"
	_device_label.text = "Device: " + device

	var devices: Array[String] = MicManager.get_device_list()
	var names: String = ""
	for i: int in range(devices.size()):
		if i > 0:
			names += ", "
		names += devices[i]
	if names.is_empty():
		names = "(none)"
	_device_list_label.text = "Devices: " + names

	_state_label.text = "State: " + MicManager.get_state_name()


func _log_event(msg: String) -> void:
	var lines: PackedStringArray = _event_log.text.split("\n")
	var keep: int = mini(lines.size(), 8)
	var trimmed: String = ""
	for i: int in range(keep):
		if i > 0:
			trimmed += "\n"
		trimmed += lines[i]
	_event_log.text = msg + "\n" + trimmed
