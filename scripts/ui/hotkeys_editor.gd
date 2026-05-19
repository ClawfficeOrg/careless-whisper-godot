## hotkeys_editor.gd
## UI component for viewing and editing in-app hotkey bindings.
## Reads from and writes to ConfigManager via get_value / set_value.
## For PTT keys, also updates InputMap so the binding takes effect immediately.
extends VBoxContainer

signal hotkey_changed(key_id: String, value: String)

## Each entry: [config_key, display_label, inputmap_action_or_empty]
const HOTKEY_DEFS: Array = [
	["mode.ptt_key_insert", "PTT key (Insert / Hold-to-talk)", "push_to_talk"],
	["mode.ptt_key_command", "PTT key (Command mode)", "push_to_talk_command"],
	["mode.command_hotkey", "Command hotkey", ""],
	["overlay.whisbar_hotkey", "Overlay hotkey", ""],
]

@onready var _rows_container: VBoxContainer = $ScrollContainer/RowsContainer


func _ready() -> void:
	_build_rows()


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _build_rows() -> void:
	for child in _rows_container.get_children():
		child.queue_free()

	for entry in HOTKEY_DEFS:
		var key_id: String = entry[0]
		var label_text: String = entry[1]
		_add_row(key_id, label_text)


func _add_row(key_id: String, label_text: String) -> void:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var edit := LineEdit.new()
	edit.text = ConfigManager.get_value(key_id, "")
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = "e.g. CapsLock"

	edit.text_submitted.connect(func(val: String) -> void: _on_hotkey_committed(key_id, val))
	edit.focus_exited.connect(func() -> void: _on_hotkey_committed(key_id, edit.text))

	row.add_child(lbl)
	row.add_child(edit)
	_rows_container.add_child(row)


func _on_hotkey_committed(key_id: String, value: String) -> void:
	var trimmed: String = value.strip_edges()
	if ConfigManager.get_value(key_id, "") == trimmed:
		return
	ConfigManager.set_value(key_id, trimmed)
	hotkey_changed.emit(key_id, trimmed)

	# For PTT keys, also update the InputMap action so it fires immediately.
	for entry in HOTKEY_DEFS:
		if entry[0] == key_id:
			var action: String = entry[2]
			if not action.is_empty():
				_register_key_action(action, trimmed)
			break


## Register a key name string as the sole event for an InputMap action.
## action must already exist in InputMap (defined in project.godot).
## key_name uses Godot's Key name format, e.g. "CapsLock", "F9", "Space".
func _register_key_action(action: String, key_name: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	InputMap.action_erase_events(action)

	if key_name.is_empty():
		return

	# Look up the keycode by name.
	var keycode: int = OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		push_warning("[HotkeysEditor] Unknown key name: '%s' — not registered" % key_name)
		return

	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	InputMap.action_add_event(action, ev)
