## config_dialog.gd
## Config dialog — model selection, language/thread settings, hotkeys,
## startup behaviour, and theme selection.
extends Window

# ---------------------------------------------------------------------------
# UI references
# ---------------------------------------------------------------------------
@onready var language_edit: LineEdit     = %LanguageEdit
@onready var threads_spin: SpinBox       = %ThreadsSpin
@onready var model_path_edit: LineEdit   = %ModelPathEdit
@onready var browse_button: Button       = %BrowseButton
@onready var load_button: Button         = %LoadModelButton
@onready var close_button: Button        = %CloseButton
@onready var mic_option: OptionButton    = %MicOption
@onready var model_browser: VBoxContainer = $MarginContainer/VBox/TabContainer/Models
@onready var _launch_on_boot: CheckBox   = %LaunchOnBootCheck
@onready var _startup_mode: OptionButton = %StartupModeOption

## Whisper node reference (injected from Main scene via set_whisper_node)
var _whisper: Node = null

## Background thread for model loading
var _load_thread: Thread = null


func _ready() -> void:
	_populate_mic_dropdown()
	_load_current_config()
	_connect_signals()


# ---------------------------------------------------------------------------
# Public
# ---------------------------------------------------------------------------

func set_whisper_node(node: Node) -> void:
	_whisper = node
	# Pass whisper reference to model browser
	if model_browser != null and model_browser.has_method("set_whisper_node"):
		model_browser.set_whisper_node(node)


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _populate_mic_dropdown() -> void:
	mic_option.clear()
	var devices := AudioServer.get_input_device_list()
	for device in devices:
		mic_option.add_item(device)
	# Select the currently active device
	var current: String = AudioServer.get_input_device()
	for i in range(mic_option.get_item_count()):
		if mic_option.get_item_text(i) == current:
			mic_option.select(i)
			break


func _load_current_config() -> void:
	# Populate the path field with the last saved path
	var saved_path: String = ConfigManager.get_value("whisper.model_path", "")
	if not saved_path.is_empty():
		model_path_edit.text = saved_path

	language_edit.text = ConfigManager.get_value("whisper.language", "en")
	threads_spin.value = ConfigManager.get_value("whisper.threads", 4)

	# Startup tab
	_launch_on_boot.pressed = ConfigManager.get_startup_enabled()
	_populate_startup_mode_option()


func _populate_startup_mode_option() -> void:
	_startup_mode.clear()
	_startup_mode.add_item("Normal")
	_startup_mode.add_item("Minimized")
	_startup_mode.add_item("System Tray")

	var mode: String = ConfigManager.get_startup_mode()
	match mode:
		"minimized":
			_startup_mode.select(1)
		"tray":
			_startup_mode.select(2)
		_:
			_startup_mode.select(0)


func _connect_signals() -> void:
	browse_button.pressed.connect(_on_browse)
	load_button.pressed.connect(_on_load_model)
	close_button.pressed.connect(hide)
	language_edit.text_changed.connect(
		func(t: String) -> void: ConfigManager.set_value("whisper.language", t)
	)
	threads_spin.value_changed.connect(
		func(v: float) -> void: ConfigManager.set_value("whisper.threads", int(v))
	)
	mic_option.item_selected.connect(_on_mic_selected)
	close_requested.connect(hide)

	_launch_on_boot.toggled.connect(_on_launch_on_boot_toggled)
	_startup_mode.item_selected.connect(_on_startup_mode_selected)

	# Connect to model browser's load request
	if model_browser != null:
		model_browser.load_model_requested.connect(_on_model_browser_load)


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_mic_selected(index: int) -> void:
	var device := mic_option.get_item_text(index)
	AudioServer.set_input_device(device)
	ConfigManager.set_value("audio.input_device", device)
	push_warning("[Config] Mic input set to: %s" % device)


func _on_model_browser_load(path: String) -> void:
	# User clicked Load in the model browser
	model_path_edit.text = path
	_on_load_model()


func _on_browse() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.bin ; GGML model files"])
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_selected.connect(func(path: String) -> void:
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

	# Disable UI while loading
	load_button.disabled = true
	load_button.text = "Loading…"
	close_button.disabled = true

	# Save the full path for next startup autoload
	ConfigManager.set_value("whisper.model_path", path)
	SignalBus.model_loading.emit(path.get_file())

	if _whisper != null and _whisper.has_method("load_model"):
		_whisper.threads = ConfigManager.get_value("whisper.threads", 4)
		_whisper.language = ConfigManager.get_value("whisper.language", "en")
		# Load in a thread to keep UI responsive
		_load_model_threaded(path)
	else:
		push_warning("[ConfigDialog] WhisperCpp node not available — placeholder mode")
		# Simulate success so the UI updates
		await get_tree().create_timer(0.5).timeout
		_finish_model_load(path.get_file(), true)
		ConfigManager.set_value("whisper.model", path.get_file().replace(".bin", ""))


func _load_model_threaded(path: String) -> void:
	# Call load_model on the main thread. The WhisperCpp extension now
	# performs non-blocking loading internally and will emit model_loaded or
	# model_load_failed via the main-thread polling channel. Calling the
	# extension from a GDScript Thread causes a cross-thread Godot API call
	# (UB) so we must invoke it on the main thread.
	call_deferred("_invoke_load_model_main", path)

func _invoke_load_model_main(path: String) -> void:
	if _whisper == null:
		return
	var success: bool = _whisper.load_model(path)
	# If the extension returns immediate success, finish; otherwise wait
	# for the model_loaded or model_load_failed signals emitted by the ext.
	if success:
		_finish_model_load(path.get_file(), true)


func _finish_model_load(model_name: String, success: bool) -> void:
	# Re-enable UI
	load_button.disabled = false
	load_button.text = "Load Model"
	close_button.disabled = false

	# Clean up thread
	if _load_thread != null and _load_thread.is_started():
		_load_thread.wait_to_finish()
		_load_thread = null

	if success:
		ConfigManager.set_value("whisper.model", model_name.replace(".bin", ""))
		SignalBus.model_ready.emit(model_name)
	else:
		SignalBus.model_load_failed.emit("Failed to load model: %s" % model_name)


func _on_launch_on_boot_toggled(enabled: bool) -> void:
	ConfigManager.set_startup_enabled(enabled)
	push_warning(
		"[ConfigDialog] launch_on_boot=%s (OS registration not yet implemented)" % enabled
	)


func _on_startup_mode_selected(index: int) -> void:
	var modes: Array[String] = ["normal", "minimized", "tray"]
	if index >= 0 and index < modes.size():
		ConfigManager.set_startup_mode(modes[index])
