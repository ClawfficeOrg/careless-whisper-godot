## model_manager.gd
## Autoload that manages whisper.cpp model downloads and discovery.
## Models are stored in user://models/
extends Node

## Emitted when a download starts
signal download_started(model_name: String)
## Emitted periodically during download with progress (0.0 - 1.0)
signal download_progress(model_name: String, progress: float)
## Emitted when download completes successfully
signal download_completed(model_name: String, path: String)
## Emitted when download fails
signal download_failed(model_name: String, error: String)

## Directory where models are stored
const MODELS_DIR := "user://models"

## Available models with their download URLs
const AVAILABLE_MODELS: Dictionary = {
	"tiny.en": {
		"filename": "ggml-tiny.en.bin",
		"url": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin",
		"size_mb": 75,
		"description": "Tiny English-only (~75 MB) - Fastest, lowest accuracy"
	},
	"tiny": {
		"filename": "ggml-tiny.bin",
		"url": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin",
		"size_mb": 75,
		"description": "Tiny multilingual (~75 MB)"
	},
	"base.en": {
		"filename": "ggml-base.en.bin",
		"url": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin",
		"size_mb": 142,
		"description": "Base English-only (~142 MB) - Good balance"
	},
	"base": {
		"filename": "ggml-base.bin",
		"url": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
		"size_mb": 142,
		"description": "Base multilingual (~142 MB)"
	},
	"small.en": {
		"filename": "ggml-small.en.bin",
		"url": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin",
		"size_mb": 466,
		"description": "Small English-only (~466 MB)"
	},
	"small": {
		"filename": "ggml-small.bin",
		"url": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
		"size_mb": 466,
		"description": "Small multilingual (~466 MB)"
	},
	"medium.en": {
		"filename": "ggml-medium.en.bin",
		"url": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin",
		"size_mb": 1500,
		"description": "Medium English-only (~1.5 GB) - High accuracy"
	},
	"medium": {
		"filename": "ggml-medium.bin",
		"url": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin",
		"size_mb": 1500,
		"description": "Medium multilingual (~1.5 GB)"
	},
}

## Active downloads (model_name -> HTTPRequest)
var _downloads: Dictionary = {}


func _ready() -> void:
	_ensure_models_dir()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## List all available model names
func get_available_models() -> Array[String]:
	var models: Array[String] = []
	for model_name in AVAILABLE_MODELS:
		models.append(model_name)
	return models


## Get info about a specific model
func get_model_info(model_name: String) -> Dictionary:
	return AVAILABLE_MODELS.get(model_name, {})


## List models that are already downloaded locally
func get_local_models() -> Array[String]:
	var models: Array[String] = []
	var dir := DirAccess.open(MODELS_DIR)
	if dir == null:
		return models

	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".bin"):
			# Map filename back to model name
			for model_name in AVAILABLE_MODELS:
				if AVAILABLE_MODELS[model_name].filename == file:
					models.append(model_name)
					break
		file = dir.get_next()
	dir.list_dir_end()

	return models


## Check if a specific model is downloaded
func is_model_downloaded(model_name: String) -> bool:
	if not AVAILABLE_MODELS.has(model_name):
		return false
	var filename: String = AVAILABLE_MODELS[model_name].filename
	return FileAccess.file_exists(MODELS_DIR.path_join(filename))


## Get the full path to a model file
func get_model_path(model_name: String) -> String:
	if not AVAILABLE_MODELS.has(model_name):
		return ""
	var filename: String = AVAILABLE_MODELS[model_name].filename
	return MODELS_DIR.path_join(filename)


## Start downloading a model. Returns false if already downloading or invalid.
func download_model(model_name: String) -> bool:
	if not AVAILABLE_MODELS.has(model_name):
		push_error("[ModelManager] Unknown model: %s" % model_name)
		return false

	if _downloads.has(model_name):
		push_warning("[ModelManager] Already downloading: %s" % model_name)
		return false

	if is_model_downloaded(model_name):
		push_warning("[ModelManager] Model already downloaded: %s" % model_name)
		return false

	var info: Dictionary = AVAILABLE_MODELS[model_name]
	var url: String = info.url
	var dest_path: String = MODELS_DIR.path_join(info.filename)

	# Create HTTP request node
	var http := HTTPRequest.new()
	http.download_file = dest_path
	http.use_threads = true
	add_child(http)

	http.request_completed.connect(_on_download_completed.bind(model_name, http))

	var err := http.request(url)
	if err != OK:
		push_error("[ModelManager] Failed to start download: %s" % err)
		http.queue_free()
		download_failed.emit(model_name, "Failed to start download")
		return false

	_downloads[model_name] = http
	download_started.emit(model_name)

	# Start progress monitoring
	_monitor_download_progress(model_name, dest_path, info.size_mb * 1024 * 1024)

	return true


## Delete a downloaded model
func delete_model(model_name: String) -> bool:
	if not AVAILABLE_MODELS.has(model_name):
		return false

	var path := get_model_path(model_name)
	if path.is_empty():
		return false

	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return err == OK


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _ensure_models_dir() -> void:
	if not DirAccess.dir_exists_absolute(MODELS_DIR):
		DirAccess.make_dir_recursive_absolute(MODELS_DIR)


func _monitor_download_progress(model_name: String, dest_path: String, expected_size: int) -> void:
	var tween := create_tween()
	tween.set_loops()

	tween.tween_callback(func():
		if not _downloads.has(model_name):
			tween.kill()
			return

		var file := FileAccess.open(dest_path, FileAccess.READ)
		if file == null:
			return

		var current_size := file.get_length()
		file.close()

		var progress := clampf(float(current_size) / float(expected_size), 0.0, 1.0)
		download_progress.emit(model_name, progress)
	).set_delay(0.25)


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, model_name: String, http: HTTPRequest) -> void:
	_downloads.erase(model_name)
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var error := "Download failed (result=%d, code=%d)" % [result, response_code]
		push_error("[ModelManager] %s" % error)
		download_failed.emit(model_name, error)
		return

	var path := get_model_path(model_name)
	download_completed.emit(model_name, path)
