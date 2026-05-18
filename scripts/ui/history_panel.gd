## history_panel.gd
## Scrollable output history panel.
## Listens to SignalBus.transcription_completed, adds timestamped rows, and
## persists up to HISTORY_LIMIT entries across sessions via user://history.json.
extends VBoxContainer

class_name HistoryPanel

## Emitted after a new entry is added.  Routed through SignalBus externally.
signal history_cleared()

const ENTRY_SCENE: PackedScene = preload("res://scenes/ui/history_entry.tscn")
const HISTORY_PATH := "user://history.json"
const HISTORY_LIMIT := 100

@onready var _scroll: ScrollContainer = $ScrollContainer
@onready var _entries_box: VBoxContainer = $ScrollContainer/EntriesBox
@onready var _clear_button: Button = $Header/ClearButton

## In-memory ordered list of persisted entry data.
var _entries: Array[Dictionary] = []


func _ready() -> void:
	_clear_button.pressed.connect(_on_clear_pressed)
	SignalBus.transcription_completed.connect(_on_transcription_completed)
	_load_history()
	_rebuild_ui()


## Add a new entry with the current system time as timestamp.
func add_entry(text: String) -> void:
	var ts: String = Time.get_datetime_string_from_system(false, true)
	_entries.append({"text": text, "timestamp": ts})
	if _entries.size() > HISTORY_LIMIT:
		_entries.pop_front()
	_save_history()
	_append_entry_node(text, ts)
	_scroll_to_bottom()
	SignalBus.history_added.emit(text, ts)


## Remove all entries from memory, disk, and the UI.
func clear() -> void:
	_entries.clear()
	_save_history()
	for child in _entries_box.get_children():
		child.queue_free()
	history_cleared.emit()


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _on_transcription_completed(text: String) -> void:
	add_entry(text)


func _on_clear_pressed() -> void:
	clear()


func _append_entry_node(text: String, timestamp: String) -> void:
	var entry: HistoryEntry = ENTRY_SCENE.instantiate() as HistoryEntry
	_entries_box.add_child(entry)
	entry.set_data(text, timestamp)


func _rebuild_ui() -> void:
	for child in _entries_box.get_children():
		child.queue_free()
	for item: Dictionary in _entries:
		_append_entry_node(item.get("text", ""), item.get("timestamp", ""))
	_scroll_to_bottom()


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _save_history() -> void:
	var file: FileAccess = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[HistoryPanel] cannot open %s for writing" % HISTORY_PATH)
		return
	file.store_string(JSON.stringify(_entries))
	file.close()


func _load_history() -> void:
	if not FileAccess.file_exists(HISTORY_PATH):
		return
	var file: FileAccess = FileAccess.open(HISTORY_PATH, FileAccess.READ)
	if file == null:
		push_warning("[HistoryPanel] cannot open %s for reading" % HISTORY_PATH)
		return
	var raw: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Array):
		return
	var arr: Array = parsed
	for item in arr:
		if item is Dictionary:
			_entries.append(item)
