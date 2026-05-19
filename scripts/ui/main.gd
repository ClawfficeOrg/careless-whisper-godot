## main.gd
## Root controller for the Careless Whisper main window.
## Coordinates audio capture, WhisperCpp extension, and UI state.
extends Control

# ---------------------------------------------------------------------------
# Child node references (resolved in _ready)
# ---------------------------------------------------------------------------
@onready var record_button: Button           = %RecordButton
@onready var output_label: RichTextLabel     = %OutputLabel
@onready var status_label: Label             = %StatusLabel
@onready var model_label: Label              = %ModelLabel
@onready var config_button: Button           = %ConfigButton
@onready var config_dialog: Window           = %ConfigDialog
@onready var mic_level_meter: Range          = %MicLevelMeter
@onready var loading_overlay: Control        = %LoadingOverlay
@onready var vim_mode_button: Button        = %VimModeButton

## Whisper GDExtension node — may be null if the extension is not built yet.
@onready var whisper: Node = %WhisperNode

# ---------------------------------------------------------------------------
# Audio capture
# ---------------------------------------------------------------------------
## AudioStreamMicrophone → captured into a ring buffer.
var _audio_player: AudioStreamPlayer
var _audio_effect: AudioEffectCapture
var _audio_bus_idx: int = -1

## PCM sample accumulator (i16 LE bytes) filled while recording.
var _pcm_buffer: PackedByteArray

## Whether a recording session is active.
var _recording: bool = false

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _whisper_available: bool = false
var _model_loaded: bool = false


func _ready() -> void:
	_detect_whisper_extension()
	_setup_ui()
	_connect_signals()
	_refresh_model_label()
	_autoload_model()


# ---------------------------------------------------------------------------
# Extension detection
# ---------------------------------------------------------------------------

func _detect_whisper_extension() -> void:
	# ClassDB.class_exists is the safe way to check for optional extensions.
	if ClassDB.class_exists("WhisperCpp"):
		_whisper_available = true
		push_warning("[main] WhisperCpp GDExtension loaded")
	else:
		_whisper_available = false
		push_warning("[main] WhisperCpp GDExtension not available — running in placeholder mode")


# ---------------------------------------------------------------------------
# UI setup
# ---------------------------------------------------------------------------

func _setup_ui() -> void:
	record_button.text = "🎤  Hold to Record"
	status_label.text  = "Ready"
	_update_vim_button()

	if not _whisper_available:
		status_label.text = "⚠ GDExtension not built — placeholder mode"
		output_label.text = (
			"[b]Build Required[/b]\n\n"
			+ "The whisper.cpp GDExtension has not been compiled yet.\n\n"
			+ "Run [code]build.sh[/code] inside [code]godot-extension/[/code] "
			+ "from the whisper.cpp fork, then copy the shared library to:\n"
			+ "[code]addons/whisper_cpp/bin/[/code]\n\n"
			+ "See [b]SPEC.md[/b] Phase 1 for full instructions."
		)


func _connect_signals() -> void:
	record_button.button_down.connect(_on_record_start)
	record_button.button_up.connect(_on_record_stop)
	config_button.pressed.connect(_on_config_pressed)
	vim_mode_button.pressed.connect(_on_vim_mode_toggled)
	CommandDispatcher.push_to_talk_pressed.connect(_on_record_start)
	CommandDispatcher.push_to_talk_released.connect(_on_record_stop)

	SignalBus.model_ready.connect(_on_model_ready)
	SignalBus.model_load_failed.connect(_on_model_load_failed)
	SignalBus.model_loading.connect(_on_model_loading)
	SignalBus.transcription_completed.connect(_on_transcription_completed)
	SignalBus.transcription_error.connect(_on_transcription_error)

	if _whisper_available and whisper != null:
		whisper.transcription_complete.connect(func(text: String) -> void:
			SignalBus.transcription_completed.emit(text)
		)
		whisper.transcription_error.connect(func(msg: String) -> void:
			SignalBus.transcription_error.emit(msg)
		)
		# model_loaded is handled by config_dialog when loading via UI.
		# For the startup autoload path, _autoload_model connects one-shot below.

	# Wire config dialog with the whisper node so it can load models
	config_dialog.set_whisper_node(whisper)

	# Wire VimController with whisper node for native cross-platform input
	VimController.set_whisper_node(whisper)


# ---------------------------------------------------------------------------
# Vim mode
# ---------------------------------------------------------------------------

func _on_vim_mode_toggled() -> void:
	VimController.enabled = not VimController.enabled
	_update_vim_button()


func _update_vim_button() -> void:
	if VimController.enabled:
		vim_mode_button.text = "Vim: ON"
	else:
		vim_mode_button.text = "Vim: OFF"


# ---------------------------------------------------------------------------
# Recording flow
# ---------------------------------------------------------------------------

func _on_record_start() -> void:
	if _recording:
		return
	_recording = true
	_pcm_buffer = PackedByteArray()
	record_button.text = "🔴  Recording…"
	status_label.text  = "Recording…"
	SignalBus.mic_started.emit()

	# Reset the level meter
	if mic_level_meter != null and mic_level_meter.has_method("reset"):
		mic_level_meter.reset()

	# Set up audio capture bus if not already done
	if _audio_bus_idx == -1:
		_setup_audio_capture()

	if _audio_player != null:
		_audio_player.play()


func _on_record_stop() -> void:
	if not _recording:
		return
	_recording = false
	record_button.text = "🎤  Hold to Record"
	status_label.text  = "Processing…"
	SignalBus.mic_stopped.emit()

	# Reset the level meter
	if mic_level_meter != null and mic_level_meter.has_method("reset"):
		mic_level_meter.reset()

	if _audio_player != null:
		_audio_player.stop()

	# Collect remaining frames from capture ring buffer
	_drain_audio_buffer()

	if _whisper_available and whisper != null and _model_loaded:
		whisper.transcribe(_pcm_buffer)
	elif not _whisper_available:
		# Placeholder — simulate a result after a short delay
		await get_tree().create_timer(0.5).timeout
		_on_transcription_completed("[placeholder] GDExtension not loaded")
	elif not _model_loaded:
		status_label.text = "No model loaded"
		_on_transcription_error("No model loaded — open Config to select one")


func _process(_delta: float) -> void:
	if _recording and _audio_effect != null:
		_drain_audio_buffer()


func _drain_audio_buffer() -> void:
	if _audio_effect == null:
		return
	var frames_available := _audio_effect.get_frames_available()
	if frames_available == 0:
		return
	var stereo: PackedVector2Array = _audio_effect.get_buffer(frames_available)

	# Calculate RMS from this batch and emit — MicMeter.gd listens via SignalBus
	var sum_sq := 0.0
	for frame: Vector2 in stereo:
		var mono := (frame.x + frame.y) * 0.5
		sum_sq += mono * mono
	var rms := sqrt(sum_sq / maxf(float(stereo.size()), 1.0))
	SignalBus.audio_level.emit(rms)

	# Whisper requires 16kHz mono i16 LE.
	# AudioEffectCapture runs at the bus mix rate (often 44100 or 48000).
	# We downsample using linear interpolation for better quality.
	var mix_rate: int = AudioServer.get_mix_rate()
	const TARGET_RATE: int = 16000
	var ratio: float = float(mix_rate) / float(TARGET_RATE)
	var output_count: int = int(round(float(stereo.size()) / ratio))

	for i in range(output_count):
		var src_idx: float = i * ratio
		var idx0: int = int(src_idx)
		var idx1: int = max(0, min(idx0 + 1, stereo.size() - 1))
		var frac: float = src_idx - float(idx0)

		# Linear interpolation between adjacent samples
		var v0: Vector2 = stereo[idx0]
		var v1: Vector2 = stereo[idx1]
		var interp: Vector2 = v0.lerp(v1, frac)

		# Convert stereo to mono and clamp
		var mono_f: float = clampf((interp.x + interp.y) * 0.5, -1.0, 1.0)
		var sample: int = int(round(mono_f * 32767.0))

		# Append as little-endian i16
		_pcm_buffer.append(sample & 0xFF)
		_pcm_buffer.append((sample >> 8) & 0xFF)


# ---------------------------------------------------------------------------
# Audio bus helpers
# ---------------------------------------------------------------------------

func _setup_audio_capture() -> void:
	# Create a dedicated "MicCapture" bus
	_audio_bus_idx = AudioServer.bus_count
	AudioServer.add_bus(_audio_bus_idx)
	AudioServer.set_bus_name(_audio_bus_idx, "MicCapture")
	AudioServer.set_bus_send(_audio_bus_idx, "Master")
	AudioServer.set_bus_mute(_audio_bus_idx, true)  # Mute so we don't get echo

	# Add capture effect
	var capture_effect := AudioEffectCapture.new()
	capture_effect.buffer_length = 0.1
	AudioServer.add_bus_effect(_audio_bus_idx, capture_effect)
	_audio_effect = capture_effect

	# Mic player
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = AudioStreamMicrophone.new()
	_audio_player.bus = "MicCapture"
	add_child(_audio_player)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_model_loading(model_name: String) -> void:
	status_label.text = "Loading model: %s" % model_name
	if loading_overlay != null and loading_overlay.has_method("show_loading"):
		loading_overlay.show_loading("Loading model: %s" % model_name)


func _on_model_ready(model_name: String) -> void:
	_model_loaded = true
	_refresh_model_label()
	status_label.text = "Model ready: %s" % model_name
	if loading_overlay != null and loading_overlay.has_method("hide_loading"):
		loading_overlay.hide_loading()


func _on_model_load_failed(error: String) -> void:
	_model_loaded = false
	status_label.text = "Model failed to load"
	output_label.text = "[color=red]Error loading model:[/color]\n%s" % error
	if loading_overlay != null and loading_overlay.has_method("hide_loading"):
		loading_overlay.hide_loading()


func _on_transcription_completed(text: String) -> void:
	status_label.text = "Done"
	output_label.text = text


func _on_transcription_error(msg: String) -> void:
	status_label.text = "Error"
	output_label.text = "[color=red]Transcription error:[/color]\n%s" % msg


func _on_config_pressed() -> void:
	config_dialog.popup_centered()


func _refresh_model_label() -> void:
	var model_name: String = ConfigManager.get_value("whisper.model", "none")
	model_label.text = "Model: %s" % model_name


func _autoload_model() -> void:
	if not _whisper_available or whisper == null:
		return
	var saved_path: String = ConfigManager.get_value("whisper.model_path", "")
	if saved_path.is_empty():
		status_label.text = "Ready — open Config to load a model"
		return
	if not FileAccess.file_exists(saved_path):
		status_label.text = "Saved model not found: %s" % saved_path
		return
	status_label.text = "Loading model…"
	whisper.threads = ConfigManager.get_value("whisper.threads", 4)
	whisper.language = ConfigManager.get_value("whisper.language", "en")
	# One-shot: when the extension signals completion, update main UI state once.
	whisper.model_loaded.connect(func(path: String) -> void:
		SignalBus.model_ready.emit(path.get_file())
	, CONNECT_ONE_SHOT)
	whisper.load_model(saved_path)
