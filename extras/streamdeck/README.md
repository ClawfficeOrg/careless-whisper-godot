# StreamDeck Plugin — Careless Whisper

This folder contains a companion
[Stream Deck plugin](https://developer.elgato.com/documentation/stream-deck/sdk/overview/)
scaffold that lets physical Stream Deck buttons control the Careless Whisper
speech-recognition app.

---

## Transport

The plugin talks to the Godot app over **HTTP POST** on `127.0.0.1:12138`
(localhost only, never reachable from the network).

See [`docs/streamdeck.md`](../../docs/streamdeck.md) for the full payload
reference, action list, security notes, and curl examples.

---

## Folder Structure

```
extras/streamdeck/
├── README.md                              ← this file
├── test-instructions.md                   ← manual verification steps
└── careless-whisper.streamDeckPlugin/
    ├── manifest.json                      ← plugin metadata + action list
    ├── plugin.js                          ← plugin runtime (JS, Stream Deck SDK v2)
    ├── assets/
    │   └── icon.png                       ← placeholder icon (replace before publish)
    └── propertyinspector/
        └── index.html                     ← per-action settings UI
```

---

## Installation (local / development)

> Requires **Stream Deck software ≥ 6.0** (Windows or macOS).

### Windows

1. Close the Stream Deck application if it is running.
2. Copy the `careless-whisper.streamDeckPlugin` folder to:
   ```
   %APPDATA%\Elgato\StreamDeck\Plugins\
   ```
3. Reopen Stream Deck. The plugin appears in the action list under
   **"Productivity → Careless Whisper"**.

### macOS

1. Quit the Stream Deck application.
2. Copy `careless-whisper.streamDeckPlugin` to:
   ```
   ~/Library/Application Support/com.elgato.StreamDeck/Plugins/
   ```
3. Relaunch Stream Deck.

---

## Available Actions

| Action | What it does |
|--------|-------------|
| **Start Recording** | POST `{"action":"start_recording"}` |
| **Stop Recording** | POST `{"action":"stop_recording"}` |
| **Toggle Mute** | POST `{"action":"toggle_mute"}` |
| **Load Model** | POST `{"action":"load_model","model":"<name>"}` |
| **Notify** | POST `{"action":"notify","message":"<text>"}` |

---

## Per-Action Settings

Open the **property inspector** by selecting an action in the Stream Deck
layout. Configure:

| Field | Default | Description |
|-------|---------|-------------|
| **Host** | `127.0.0.1` | IP/hostname of the Godot app |
| **Port** | `12138` | HTTP server port |
| **Shared Secret** | _(empty)_ | Must match `streamdeck/secret` in the Godot project settings |
| **Model Name** | `tiny.en` | _(Load Model only)_ whisper.cpp model to load |
| **Message** | _(empty)_ | _(Notify only)_ Text to send as the notification payload |

---

## Replacing the Placeholder Icon

`assets/icon.png` is a minimal greyscale placeholder. Replace it with a
proper 72×72 px (or 144×144 px @2×) PNG before publishing to the Elgato
marketplace. The `manifest.json` also references `assets/category-icon`
for the action-category icon — add that file as well.

---

## Publishing

Publishing to the Elgato marketplace requires:
1. A registered [Elgato developer account](https://developer.elgato.com/).
2. Signing the plugin bundle with `DistributionTool` (provided by Elgato).
3. No developer certificate is needed for local installs.

---

## Security Notes

- The HTTP server binds to `127.0.0.1` only.
- Use the **Shared Secret** field to authenticate requests if the host is
  shared with untrusted users.
- Never commit a real secret; use a local `override.cfg` in the Godot project
  to set `streamdeck/secret` at runtime.
