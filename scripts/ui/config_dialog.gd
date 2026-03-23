## config_dialog.gd
## Config dialog — model selection, language settings, and mic input device.
extends Window

# ---------------------------------------------------------------------------
# UI references
# ---------------------------------------------------------------------------
@onready var model_option: OptionButton  = %ModelOption
@onready var language_edit: LineEdit     = %LanguageEdit
@onready var threads_spin: SpinBox       = %ThreadsSpin
@onready var model_path_edit: LineEdit   = %ModelPathEdit
@onready var browse_button: Button       = %BrowseButton
@onready var load_button: Button         = %LoadModelButton
@onready var close_button: Button        = %CloseButton
@onready var mic_option: OptionButton    = %MicOption

## Whisper node reference (injected from Main scene via set_whisper_node)
var _whisper: Node = null

# Pre-defined model names for the dropdown
const KNOWN_MODELS: Array[String] = [
	"ggml-tiny.en.bin",
	"ggml-base.en.bin",
	"ggml-small.en.bin",
	"ggml-medium.en.bin",
]


func _ready() -> void:
	_populate_model_dropdown()
	_populate_mic_dropdown()
	_load_current_config()
	_connect_signals()


# ---------------------------------------------------------------------------
# Public
# ---------------------------------------------------------------------------

func set_whisper_node(node: Node) -> void:
	_whisper = node


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _populate_model_dropdown() -> void:
	model_option.clear()
	for name in KNOWN_MODELS:
		model_option.add_item(name)
	model_option.add_item("Custom…")


func _populate_mic_dropdown() -> void:
	mic_option.clear()
	var devices := AudioServer.get_input_device_list()
	for device in devices:
		mic_option.add_item(device)
	# Select the currently active device
	var current := AudioServer.get_input_device()
	for i in mic_option.item_count:
		if mic_option.get_item_text(i) == current:
			mic_option.select(i)
			break


func _load_current_config() -> void:
	var current_model: String = ConfigManager.get_value("whisper.model", "base.en")
	for i in model_option.item_count:
		if model_option.get_item_text(i).contains(current_model):
			model_option.select(i)
			break

	# Populate the path field with the last saved path
	var saved_path: String = ConfigManager.get_value("whisper.model_path", "")
	if not saved_path.is_empty():
		model_path_edit.text = saved_path

	language_edit.text = ConfigManager.get_value("whisper.language", "en")
	threads_spin.value = ConfigManager.get_value("whisper.threads", 4)


func _connect_signals() -> void:
	model_option.item_selected.connect(_on_model_selected)
	browse_button.pressed.connect(_on_browse)
	load_button.pressed.connect(_on_load_model)
	close_button.pressed.connect(hide)
	language_edit.text_changed.connect(func(t): ConfigManager.set_value("whisper.language", t))
	threads_spin.value_changed.connect(func(v): ConfigManager.set_value("whisper.threads", int(v)))
	mic_option.item_selected.connect(_on_mic_selected)
	close_requested.connect(hide)


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_model_selected(index: int) -> void:
	var text := model_option.get_item_text(index)
	if text == "Custom…":
		return  # User will browse
	ConfigManager.set_value("whisper.model", text.replace(".bin", "").replace("ggml-", ""))


func _on_mic_selected(index: int) -> void:
	var device := mic_option.get_item_text(index)
	AudioServer.set_input_device(device)
	ConfigManager.set_value("audio.input_device", device)
	print("[Config] Mic input set to: %s" % device)


func _on_browse() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.bin ; GGML model files"])
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_selected.connect(func(path: String):
		model_path_edit.text = path
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))


func _on_load_model() -> void:
	var path := model_path_edit.text.strip_edges()
	if path.is_empty():
		push_warning("[ConfigDialog] no model path specified")
		return

	# Save the full path for next startup autoload
	ConfigManager.set_value("whisper.model_path", path)
	SignalBus.model_loading.emit(path.get_file())

	if _whisper != null and _whisper.has_method("load_model"):
		_whisper.threads = ConfigManager.get_value("whisper.threads", 4)
		_whisper.language = ConfigManager.get_value("whisper.language", "en")
		_whisper.load_model(path)
	else:
		push_warning("[ConfigDialog] WhisperCpp node not available — placeholder mode")
		# Simulate success so the UI updates
		await get_tree().create_timer(0.3).timeout
		SignalBus.model_ready.emit(path.get_file())
		ConfigManager.set_value("whisper.model", path.get_file().replace(".bin", ""))
