## history_panel_test.gd
## Manual test scene for the HistoryPanel output history feature.
##
## Buttons emit fake transcriptions to verify entry rendering, text wrapping,
## auto-scroll behaviour, timestamp formatting, and persistence across restarts.
##
## Run in editor: open scenes/test/history_panel_test.tscn and press F5.
extends Control

@onready var _history_panel: HistoryPanel = $VBox/HistoryPanel
@onready var _status_label: Label = $VBox/StatusLabel

var _fake_count: int = 0


func _ready() -> void:
	$VBox/ButtonRow/AddFakeBtn.pressed.connect(_on_add_fake_pressed)
	$VBox/ButtonRow/AddLongBtn.pressed.connect(_on_add_long_pressed)
	$VBox/ButtonRow/AddTenBtn.pressed.connect(_on_add_ten_pressed)
	$VBox/ButtonRow/ClearBtn.pressed.connect(_on_clear_pressed)

	SignalBus.history_added.connect(_on_history_added)
	_history_panel.history_cleared.connect(_on_history_cleared)

	_status_label.text = "Ready — use buttons to test HistoryPanel"


func _on_add_fake_pressed() -> void:
	_fake_count += 1
	_history_panel.add_entry("Fake transcription entry #%d. Hello world." % _fake_count)
	_status_label.text = "Added short entry #%d" % _fake_count


func _on_add_long_pressed() -> void:
	_fake_count += 1
	var text: String = (
		"Long transcription entry #%d — tests text wrapping inside the history panel. "
		+ "This sentence is intentionally verbose to verify that the RichTextLabel "
		+ "wraps correctly without truncating any content in the scrollable list."
	) % _fake_count
	_history_panel.add_entry(text)
	_status_label.text = "Added long entry #%d" % _fake_count


func _on_add_ten_pressed() -> void:
	for i: int in range(10):
		_fake_count += 1
		_history_panel.add_entry("Batch entry #%d of 10." % _fake_count)
	_status_label.text = "Added 10 batch entries (total: %d)" % _fake_count


func _on_clear_pressed() -> void:
	_history_panel.clear()


func _on_history_added(text: String, timestamp: String) -> void:
	_status_label.text = "✓ history_added fired [%s] — %d chars" % [timestamp, text.length()]


func _on_history_cleared() -> void:
	_fake_count = 0
	_status_label.text = "History cleared"
