## config_manager.gd
## Autoload that stores and retrieves user configuration with dot-notation keys.
## Config is persisted to user://config.cfg between sessions.
extends Node

const CONFIG_PATH := "user://config.cfg"

## In-memory store of all config values.
var _data: Dictionary = {}

## Defaults — applied when a key is not present in the saved config.
const DEFAULTS: Dictionary = {
	"whisper.model": "base.en",
	"whisper.language": "en",
	"whisper.threads": 4,
	"whisper.temperature": 0.0,
	"whisper.beam_size": 5,
	"audio.input_device": "",
	"audio.vad_threshold": 0.01,
	"audio.silence_timeout_ms": 1500,
	"input.mode": "push_to_talk",
	"output.default_route": "clipboard",
}


func _ready() -> void:
	_data = DEFAULTS.duplicate(true)
	_load()


## Get a config value. Returns the default if the key is unknown.
func get_value(key: String, default: Variant = null) -> Variant:
	if _data.has(key):
		return _data[key]
	return default


## Set a config value and persist to disk.
func set_value(key: String, value: Variant) -> void:
	_data[key] = value
	_save()
	SignalBus.config_changed.emit(key, value)


# ---------------------------------------------------------------------------
# Persistence helpers
# ---------------------------------------------------------------------------

func _save() -> void:
	var cfg := ConfigFile.new()
	for key: String in _data:
		var parts := key.split(".", false, 1)
		var section := parts[0] if parts.size() > 0 else "general"
		var prop := parts[1] if parts.size() > 1 else key
		cfg.set_value(section, prop, _data[key])
	var err := cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("[ConfigManager] could not save config: %s" % err)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return  # First run — defaults are already applied
	for section in cfg.get_sections():
		for prop in cfg.get_section_keys(section):
			_data["%s.%s" % [section, prop]] = cfg.get_value(section, prop)
