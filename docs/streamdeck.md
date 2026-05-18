# StreamDeck HTTP Integration

Careless Whisper exposes a tiny HTTP server (port **12138** by default) that lets
ElGato StreamDeck buttons (or any HTTP-capable automation tool) trigger in-app
actions via a simple JSON POST.

---

## Architecture

```
StreamDeck (HTTP action)
        │
        ▼
StreamDeckServer (autoload)   — listens on 127.0.0.1:PORT
        │  action_received(action_id, payload)
        ▼
StreamDeckHandlers (autoload) — dispatches to handler Callables
        │  action_executed(action_id, result)
        ▼
SignalBus / autoloads         — ConfigManager, ModelManager, etc.
```

---

## Payload Format

Send an HTTP `POST` to `http://127.0.0.1:12138/` with:

```
Content-Type: application/json

{
  "action": "<action_id>",
  ... optional extra fields ...
}
```

The server replies with:

```json
{ "status": "ok", "action": "<action_id>" }
```

or an error:

```json
{ "error": "description" }
```

---

## Built-in Actions

| `action` value    | Extra fields required          | Effect                                      |
|-------------------|-------------------------------|---------------------------------------------|
| `start_recording` | none                          | Emits `SignalBus.mic_started`               |
| `stop_recording`  | none                          | Emits `SignalBus.mic_stopped`               |
| `toggle_mute`     | none                          | Toggles `ConfigManager` `audio.muted` flag  |
| `load_model`      | `"model": "<model_name>"`     | Calls `ModelManager.start_download(name)`   |
| `notify`          | `"message": "<text>"`         | Emits `SignalBus.streamdeck_notification`   |

### Examples (curl)

```bash
# Start recording
curl -X POST http://127.0.0.1:12138/ \
  -H "Content-Type: application/json" \
  -d '{"action":"start_recording"}'

# Load tiny.en model
curl -X POST http://127.0.0.1:12138/ \
  -H "Content-Type: application/json" \
  -d '{"action":"load_model","model":"tiny.en"}'

# Send a notification
curl -X POST http://127.0.0.1:12138/ \
  -H "Content-Type: application/json" \
  -d '{"action":"notify","message":"Recording complete!"}'
```

---

## Security

### Localhost-only binding

The server always binds to `127.0.0.1` — it is never reachable from the network.

### Shared secret (recommended for production)

Set a shared secret in `project.godot` (or via `ProjectSettings`):

```
[streamdeck]
port = 12138
secret = "your-secret-token"
```

Then add the header to every StreamDeck HTTP action:

```
X-StreamDeck-Secret: your-secret-token
```

Requests missing or supplying the wrong token are rejected with HTTP 403.

> **Do not commit your real secret to source control.** Use a local override or
> environment-specific `override.cfg` file instead.

### Windows firewall note

On Windows, the first time the app listens on port 12138 you may see a Windows
Defender Firewall prompt. Since the server binds to `127.0.0.1` only, you can
safely click **Allow** (or **Cancel** — external traffic is blocked regardless).
If you use a firewall that blocks loopback traffic, allow inbound TCP on port 12138
from 127.0.0.1.

---

## Configuration Reference

Set in `project.godot` under `[streamdeck]` or via `ProjectSettings`:

| Setting              | Default  | Description                                  |
|----------------------|----------|----------------------------------------------|
| `streamdeck/port`    | `12138`  | TCP port to listen on                        |
| `streamdeck/secret`  | `""`     | Shared secret (empty = no auth required)     |

---

## Registering Custom Actions

In any autoload or scene script:

```gdscript
func _ready() -> void:
    if has_node("/root/StreamDeckHandlers"):
        StreamDeckHandlers.register_handler(
            "my_action",
            func(payload: Dictionary) -> Dictionary:
                # ... do something ...
                return {"action_id": "my_action", "success": true, "message": "done"}
        )
```

---

## StreamDeck Plugin Setup

1. In the StreamDeck software add a **"Website"** or **"HTTP Request"** action.
2. Set the URL to `http://127.0.0.1:12138/`.
3. Set Method to **POST**, Content-Type to `application/json`.
4. Set the body to the desired JSON payload (e.g. `{"action":"start_recording"}`).
5. If using a secret, add the custom header `X-StreamDeck-Secret: <your-token>`.

> The built-in StreamDeck "Website" action opens a browser. Use the
> **"Advanced Launcher"** or a community plugin such as
> [BarRaider's Super Macro](https://github.com/BarRaider/streamdeck-supermacro)
> that supports raw HTTP requests.

---

## Manual Test Scene

Open `scenes/test/streamdeck_test.tscn` in the Godot editor and press **F5** (or
run via the editor play button) to launch the test harness:

1. The status label shows the server port and whether it is listening.
2. Click each button to POST the corresponding sample action.
3. The log area displays the HTTP response and handler result.
4. Use the curl examples above from a separate terminal to test independently.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "Failed to bind" in godot.log | Port 12138 already in use | Change `streamdeck/port` to another value |
| HTTP 403 | Wrong or missing secret header | Set the correct `X-StreamDeck-Secret` value |
| Handler not found | Action ID typo | Check `StreamDeckHandlers.get_action_ids()` |
| No response | Server not started | Check `StreamDeckServer.is_listening()` |
