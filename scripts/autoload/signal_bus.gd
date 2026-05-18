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
# Macro events — emitted when a voice macro is triggered
signal macro_triggered(macro_name: String, meta: Dictionary)

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
# Commands (task-7)
# ---------------------------------------------------------------------------
## Emitted by CommandDispatcher for every matched command verb.
signal command_detected(command: String, args: Dictionary)
## Emitted by CommandDispatcher when a window management command is parsed.
signal window_command(action: String, target: String, params: Dictionary)

# ---------------------------------------------------------------------------
# OS control
# ---------------------------------------------------------------------------
signal focus_window_result(success: bool, message: String)

# ---------------------------------------------------------------------------
# Tray
# ---------------------------------------------------------------------------
signal tray_menu_selected(item_id: String)

# ---------------------------------------------------------------------------
# StreamDeck (task-8)
# ---------------------------------------------------------------------------

## Emitted by StreamDeckHandlers after an action handler completes.
signal streamdeck_action_executed(action_id: String, result: Dictionary)

## Emitted by the notify action handler with the notification message.
signal streamdeck_notification(message: String)

# ---------------------------------------------------------------------------
# Mic hot-swap (task-11)
# ---------------------------------------------------------------------------
## Emitted by MicManager when the active input device disappears.
signal mic_device_disconnected(device_id: String)
## Emitted by MicManager when the previously lost device is detected again.
signal mic_device_reconnected(device_id: String)
## Emitted by MicManager periodically during reconnect (0.0–100.0).
signal mic_reconnect_progress(percent: float)
## Emitted by MicManager and OSController when the input device list changes.
signal mic_device_list_changed(devices: Array)
## Emitted by MicManager when its internal state machine transitions.
signal mic_state_changed(state: String)

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------
signal app_quitting()
