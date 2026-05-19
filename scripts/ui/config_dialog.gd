## config_dialog.gd
## Config dialog — model selection, language/thread settings, hotkeys,
## startup behaviour, and theme selection.
extends Window

# ---------------------------------------------------------------------------
# UI references
# ---------------------------------------------------------------------------
@onready var language_edit: LineEdit     = %LanguageEdit
@onready var threads_spin: SpinBox       = %ThreadsSpin
@onready var close_button: Button        = %CloseButton
@onready var mic_option: OptionButton    = %MicOption
@onready var model_browser: VBoxContainer = $MarginContainer/VBox/TabContainer/Models
@onready var _launch_on_boot: CheckBox   = %LaunchOnBootCheck
@onready var _startup_mode: OptionButton = %StartupModeOption
@onready var _ptt_mode_option: OptionButton = %PTTModeOption

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
	language_edit.text = ConfigManager.get_value("whisper.language", "en")
	threads_spin.value = ConfigManager.get_value("whisper.threads", 4)

	# Startup tab
	_launch_on_boot.button_pressed = ConfigManager.get_startup_enabled()
	_populate_startup_mode_option()

	# PTT tab
	_populate_ptt_mode_option()


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


func _populate_ptt_mode_option() -> void:
	_ptt_mode_option.clear()
	_ptt_mode_option.add_item("Hold to talk")
	_ptt_mode_option.add_item("Toggle (tap)")
	var mode: String = ConfigManager.get_ptt_mode()
	_ptt_mode_option.select(1 if mode == "toggle" else 0)


func _connect_signals() -> void:
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
	_ptt_mode_option.item_selected.connect(_on_ptt_mode_selected)

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
	if path.is_empty():
		return
	close_button.disabled = true
	ConfigManager.set_value("whisper.model_path", path)
	SignalBus.model_loading.emit(path.get_file())
	if _whisper != null and _whisper.has_method("load_model"):
		_whisper.threads = ConfigManager.get_value("whisper.threads", 4)
		_whisper.language = ConfigManager.get_value("whisper.language", "en")
		_load_model_threaded(path)
	else:
		push_warning("[ConfigDialog] WhisperCpp node not available — placeholder mode")
		await get_tree().create_timer(0.5).timeout
		_finish_model_load(path.get_file(), true)
		ConfigManager.set_value("whisper.model", path.get_file().replace(".bin", ""))


func _load_model_threaded(path: String) -> void:
	call_deferred("_invoke_load_model_main", path)


func _invoke_load_model_main(path: String) -> void:
	if _whisper == null:
		return
	push_warning("[config_dialog] _invoke_load_model_main calling load_model: %s" % path)
	# extension finishes loading asynchronously. Do NOT call _finish_model_load
	# synchronously — load_model() returning true just means "accepted", not "done".
	if not _whisper.is_connected("model_loaded", _on_whisper_model_loaded):
		_whisper.model_loaded.connect(_on_whisper_model_loaded, CONNECT_ONE_SHOT)
	_whisper.load_model(path)


func _on_whisper_model_loaded(path: String) -> void:
	_finish_model_load(path.get_file(), true)


func _finish_model_load(model_name: String, success: bool) -> void:
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


func _on_ptt_mode_selected(index: int) -> void:
	var modes: Array[String] = ["hold", "toggle"]
	if index >= 0 and index < modes.size():
		CommandDispatcher.set_ptt_mode(modes[index])
