## transcription_e2e.gd
## End-to-end transcription test for the WhisperCpp GDExtension.
## Headless-capable: extends Node (no UI Controls), exits with a status code
## when the test finishes.  Skips gracefully when the extension or a model
## is not available so CI stays green even on machines without a built DLL.
##
## Run headless:
##   godot --headless --quit-after 60 --main-scene res://scenes/test/transcription_e2e.tscn
## Run in editor:
##   Open scenes/test/transcription_e2e.tscn and press F5.
extends Node

## Path to the bundled deterministic test audio (1 s silence, 16 kHz mono i16 LE).
const TEST_AUDIO_PATH: String = "res://assets/test_audio/short_en.wav"

## Standard minimal WAV header is exactly 44 bytes (RIFF/fmt/data chunks).
const WAV_HEADER_SIZE: int = 44

## Hard deadline — headless Godot should also pass --quit-after, but this
## guard prevents the process hanging indefinitely in editor runs.
const TIMEOUT_SECONDS: float = 30.0

var _whisper: Object = null
var _finished: bool = false


func _ready() -> void:
	if not ClassDB.class_exists("WhisperCpp"):
		push_warning(
			"[E2E] WhisperCpp GDExtension not loaded — skipping test (PASS)"
		)
		_finish(true)
		return

	var model_path: String = _find_model_path()
	if model_path.is_empty():
		push_warning(
			"[E2E] No model found in user://models — skipping test (PASS)"
		)
		_finish(true)
		return

	_whisper = ClassDB.instantiate("WhisperCpp")
	add_child(_whisper)

	_whisper.model_loaded.connect(_on_model_loaded)
	_whisper.transcription_complete.connect(_on_transcription_complete)
	_whisper.transcription_error.connect(_on_transcription_error)

	_whisper.language = "en"
	_whisper.threads = 1

	push_warning("[E2E] Loading model: %s" % model_path)
	var ok: bool = _whisper.load_model(model_path)
	if not ok:
		push_error("[E2E] load_model returned false — FAIL")
		_finish(false)
		return

	get_tree().create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)



func _find_model_path() -> String:
	if not has_node("/root/ModelManager"):
		return ""
	var locals: Array[String] = ModelManager.get_local_models()
	if locals.is_empty():
		return ""
	var name: String = locals[0]
	return ModelManager.get_model_path(name)



func _on_model_loaded(path: String) -> void:
	push_warning("[E2E] Model loaded (%s) — sending test audio" % path.get_file())
	var pcm: PackedByteArray = _load_pcm_from_wav(TEST_AUDIO_PATH)
	if pcm.is_empty():
		push_error("[E2E] Failed to load test audio: %s — FAIL" % TEST_AUDIO_PATH)
		_finish(false)
		return
	_whisper.transcribe(pcm)



func _on_transcription_complete(text: String) -> void:
	push_warning('[E2E] Transcription complete: "%s" — PASS' % text)
	_finish(true)



func _on_transcription_error(msg: String) -> void:
	push_error("[E2E] Transcription error: %s — FAIL" % msg)
	_finish(false)



func _on_timeout() -> void:
	if _finished:
		return
	push_error(
		"[E2E] Timed out after %.0f seconds — FAIL" % TIMEOUT_SECONDS
	)
	_finish(false)



## Read the raw PCM payload from a WAV file by skipping the 44-byte header.
## Assumes the WAV was generated with the standard RIFF/fmt/data layout that
## assets/test_audio/short_en.wav uses (no extra metadata chunks).
func _load_pcm_from_wav(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var all_bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if all_bytes.size() <= WAV_HEADER_SIZE:
		return PackedByteArray()
	return all_bytes.slice(WAV_HEADER_SIZE)



func _finish(success: bool) -> void:
	if _finished:
		return
	_finished = true
	if success:
		push_warning("[E2E] Test result: PASS")
	else:
		push_error("[E2E] Test result: FAIL")
	# Allow one frame so output flushes before the process exits.
	await get_tree().process_frame
	get_tree().quit(0 if success else 1)
