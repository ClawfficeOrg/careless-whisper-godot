## whisper_extension_ci_test.gd
## Smoke test: verifies WhisperCpp is registered in ClassDB.
## Headless-capable; exits 0 on success, 1 on failure.
## Skips gracefully when the extension DLL is absent (CI without a built DLL).
##
## Run headless:
##   godot --headless --quit-after 10 \
##         --main-scene res://scenes/test/whisper_extension_ci_test.tscn
## Run in editor:
##   Open scenes/test/whisper_extension_ci_test.tscn and press F5.
extends Node


func _ready() -> void:
	if not ClassDB.class_exists("WhisperCpp"):
		push_warning(
			"[CI smoke] WhisperCpp not in ClassDB — extension DLL absent or not loaded (SKIP)"
		)
		await get_tree().process_frame
		get_tree().quit(0)
		return

	var instance: Object = ClassDB.instantiate("WhisperCpp")
	if instance == null:
		push_error("[CI smoke] ClassDB.instantiate('WhisperCpp') returned null — FAIL")
		await get_tree().process_frame
		get_tree().quit(1)
		return

	var has_load_model: bool = instance.has_method("load_model")
	var has_transcribe: bool = instance.has_method("transcribe")
	var has_is_loaded: bool = instance.has_method("is_model_loaded")

	if not (has_load_model and has_transcribe and has_is_loaded):
		push_error(
			"[CI smoke] WhisperCpp missing expected methods "
			+ "(load_model=%s, transcribe=%s, is_model_loaded=%s) — FAIL"
			% [has_load_model, has_transcribe, has_is_loaded]
		)
		await get_tree().process_frame
		get_tree().quit(1)
		return

	push_warning(
		"[CI smoke] WhisperCpp found in ClassDB with all required methods — PASS"
	)
	await get_tree().process_frame
	get_tree().quit(0)
