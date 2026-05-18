## signal_bus.gd
## Global SignalBus autoload — all major subsystem events flow through here.
## No direct cross-system references; subscribe to what you need.
extends Node

# ---------------------------------------------------------------------------
# Transcription
# ---------------------------------------------------------------------------
signal transcription_segment(text: String, start_ms: int, end_ms: int, is_final: bool)
signal transcription_completed(full_text: String)
signal transcription_error(error: String)

# ---------------------------------------------------------------------------
# Audio / recording
# ---------------------------------------------------------------------------
signal mic_started()
signal mic_stopped()
signal audio_level(level_db: float)
signal voice_activity(active: bool)

# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------
signal model_changed(model_name: String)
signal model_loading(model_name: String)
signal model_ready(model_name: String)
signal model_load_failed(error: String)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
signal config_changed(key: String, value: Variant)
signal theme_changed(theme_id: String)

# ---------------------------------------------------------------------------
# OS control
# ---------------------------------------------------------------------------
signal focus_window_result(success: bool, message: String)

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------
signal app_quitting()
