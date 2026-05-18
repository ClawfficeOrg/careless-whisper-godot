## theme_selector.gd
## UI component for choosing the application colour theme.
## Persists the selection via ConfigManager and emits theme_selected.
extends VBoxContainer

signal theme_selected(theme_id: String)

## Each entry: {id, label, description}
const THEMES: Array = [
	{"id": "dark", "label": "Dark", "description": "Dark background with light text."},
	{"id": "light", "label": "Light", "description": "Light background with dark text."},
	{
		"id": "high_contrast",
		"label": "High Contrast",
		"description": "Maximum readability with bold contrast.",
	},
]

@onready var _theme_option: OptionButton = $ThemeOption
@onready var _preview_label: Label = $PreviewLabel


func _ready() -> void:
	_populate_options()
	_load_current()
	_theme_option.item_selected.connect(_on_theme_selected)


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _populate_options() -> void:
	_theme_option.clear()
	for entry in THEMES:
		_theme_option.add_item(entry["label"])


func _load_current() -> void:
	var current: String = ConfigManager.get_value("ui.theme", "dark")
	for i in THEMES.size():
		var entry_id: String = THEMES[i]["id"]
		if entry_id == current:
			_theme_option.select(i)
			_update_preview(i)
			return


func _on_theme_selected(index: int) -> void:
	var theme_id: String = THEMES[index]["id"]
	ConfigManager.set_value("ui.theme", theme_id)
	SignalBus.theme_changed.emit(theme_id)
	theme_selected.emit(theme_id)
	_update_preview(index)


func _update_preview(index: int) -> void:
	var description: String = THEMES[index]["description"]
	_preview_label.text = description
