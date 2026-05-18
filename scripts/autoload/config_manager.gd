## config_manager.gd
## Autoload that stores and retrieves user configuration with dot-notation keys.
## Config is persisted to user://config.cfg between sessions.
extends Node

const CONFIG_PATH := "user://config.cfg"

## In-memory store of all config values.
var _data: Dictionary = {}

## Defaults — applied when a key is not present in the saved config.
## Keys marked [placeholder] have no active effect yet — see docs/vim-plan/README.md
## for the versioned release plan that will implement them.
const DEFAULTS: Dictionary = {
	# --- Whisper / transcription ---
	"whisper.model": "base.en",
	"whisper.language": "en",
	"whisper.threads": 4,
	"whisper.temperature": 0.0,
	"whisper.beam_size": 5,

	# --- Audio ---
	"audio.input_device": "",
	"audio.vad_threshold": 0.01,
	"audio.silence_timeout_ms": 1500,

	# --- Legacy input/output ---
	"input.mode": "push_to_talk",
	"output.default_route": "clipboard",

	# --- v0.1: Modal voice mode & PTT ---
	"mode.current": "insert",
	"mode.ptt_key_insert": "CapsLock",
	"mode.ptt_key_command": "Super+CapsLock",
	"mode.ptt_key_visual": "",
	"mode.insert_paste_on_release": false,
	"mode.auto_detect_text_focus": true,

	# --- v0.1: Command mode verbs ---
	"command.prefix": "",
	"command.universal_copy": "Control+c",
	"command.universal_paste": "Control+v",
	"command.universal_cut": "Control+x",
	"command.universal_close": "Control+w",
	"command.vim_scroll_lines": 3,

	# --- v0.2: Window management & OS hotkey ---
	"mode.command_hotkey": "Super+CapsLock",
	"windows.list_all_enabled": true,
	"windows.fuzzy_match_threshold": 0.6,
	"windows.exclude_patterns": "",

	# --- v0.3: Overlay system [placeholder] ---
	"overlay.whichkey_enabled": true,
	"overlay.whichkey_delay_ms": 800,
	"overlay.opacity": 0.85,
	"overlay.position": "bottom-right",
	"overlay.hint_charset": "asdfjkl;",
	"overlay.whisbar_hotkey": "Super+Space",
	"overlay.font_size": 14,

	# --- v0.4: App bridges [placeholder] ---
	"bridge.browser.cdp_port": 9222,
	"bridge.browser.protocol": "cdp",
	"bridge.browser.firefox_port": 4444,
	"bridge.vscode.enabled": true,
	"bridge.vscode.binary_path": "code",
	"bridge.vscode.use_lsp": false,

	# --- v0.5: Accessibility reader [placeholder] ---
	"accessibility.enabled": true,
	"accessibility.ocr_fallback": false,
	"accessibility.click_highlight_ms": 300,

	# --- v0.6: macOS permissions [placeholder] ---
	"macos.request_accessibility_on_start": true,
	"macos.request_screen_recording_on_start": true,

	# --- v0.7: BYOK AI intent resolution [placeholder] ---
	# NOTE: ai.api_key is intentionally omitted — store in OS keychain only.
	"ai.enabled": false,
	"ai.backend": "openai",
	"ai.endpoint_url": "",
	"ai.model": "gpt-4o-mini",
	"ai.intent_threshold": 0.7,
	"ai.system_prompt": "",

	# --- v0.8: MCP command sources [placeholder] ---
	"mcp.enabled": false,
	"mcp.servers": "",

	# --- v0.9: OCR fallback [placeholder] ---
	"ocr.enabled": false,
	"ocr.language": "eng",
	"ocr.confidence_threshold": 0.75,

	# --- UI / appearance ---
	"ui.theme": "dark",

	# --- Startup behaviour ---
	"startup.launch_on_boot": false,
	"startup.window_mode": "normal",
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
# Convenience: hotkeys
# ---------------------------------------------------------------------------

## Return the stored hotkey string for the given config key.
func get_hotkey(key_id: String) -> String:
	return get_value(key_id, "")


## Persist a hotkey string and notify listeners.
func set_hotkey(key_id: String, value: String) -> void:
	set_value(key_id, value)


# ---------------------------------------------------------------------------
# Convenience: theme
# ---------------------------------------------------------------------------

## Return the active theme identifier (e.g. "dark", "light", "high_contrast").
func get_theme_id() -> String:
	return get_value("ui.theme", "dark")


## Persist a theme identifier.
func set_theme_id(theme_id: String) -> void:
	set_value("ui.theme", theme_id)


# ---------------------------------------------------------------------------
# Convenience: startup
# ---------------------------------------------------------------------------

## Return whether the app should launch at system startup.
func get_startup_enabled() -> bool:
	return get_value("startup.launch_on_boot", false)


## Persist the launch-at-startup preference.
func set_startup_enabled(enabled: bool) -> void:
	set_value("startup.launch_on_boot", enabled)


## Return the startup window mode string (e.g. "normal", "minimized", "tray").
func get_startup_mode() -> String:
	return get_value("startup.window_mode", "normal")


## Persist the startup window mode.
func set_startup_mode(mode: String) -> void:
	set_value("startup.window_mode", mode)


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
