# StreamDeck Plugin — Manual Test Instructions

Follow these steps to verify the plugin scaffold works end-to-end.

---

## Prerequisites

- Stream Deck software ≥ 6.0 installed.
- Careless Whisper Godot app running (press **F5** in the editor or run `./run.sh`).
- Plugin installed to the Plugins folder (see `README.md`).

---

## Step 1 — Verify App is Listening

```bash
curl -s -X POST http://127.0.0.1:12138/ \
  -H "Content-Type: application/json" \
  -d '{"action":"notify","message":"ping"}' | python3 -m json.tool
```

Expected response:
```json
{ "status": "ok", "action": "notify" }
```

If you see a connection-refused error, check that the Godot app is running and
that `StreamDeckServer` autoload is enabled.

---

## Step 2 — Plugin Appears in Stream Deck

1. Open the Stream Deck application.
2. In the action panel on the right, scroll to **Productivity**.
3. Confirm **Careless Whisper** is listed with at least one action.

---

## Step 3 — Drag and Configure Start Recording

1. Drag **Start Recording** onto a key.
2. In the property inspector that appears:
   - Leave **Host** and **Port** at their defaults (`127.0.0.1`, `12138`).
   - Leave **Shared Secret** empty (unless you configured one).
3. Press the key on the Stream Deck hardware (or click it in the app).
4. Confirm the key shows a brief ✓ (green tick).
5. In the Godot app, confirm that recording starts (mic indicator becomes active).

---

## Step 4 — Stop Recording

1. Drag **Stop Recording** onto another key.
2. Press it.
3. Confirm the key shows a ✓ and the Godot app stops recording.

---

## Step 5 — Toggle Mute

1. Drag **Toggle Mute** onto a key.
2. Press it once; confirm mute is enabled in the Godot app.
3. Press again; confirm mute is disabled.

---

## Step 6 — Load Model

1. Drag **Load Model** onto a key.
2. In the property inspector, select a model (e.g. `tiny.en`).
3. Press the key.
4. Confirm a model-download or model-load progress appears in the Godot app.
5. On success the key shows ✓; on error (e.g. network unavailable) it shows ✗ (red ×).

---

## Step 7 — Notify

1. Drag **Notify** onto a key.
2. In the property inspector, enter a message such as `Hello from StreamDeck`.
3. Press the key.
4. Confirm the Godot app displays or logs the notification.

---

## Step 8 — Wrong Secret (optional)

1. In the Godot project settings, set `streamdeck/secret` to `test-secret`.
2. In the property inspector for any action, leave **Shared Secret** empty.
3. Press the key — confirm it shows ✗ (server returns HTTP 403).
4. Enter `test-secret` in the **Shared Secret** field.
5. Press the key again — confirm ✓.
6. Reset `streamdeck/secret` to empty after the test.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Key always shows ✗ | App not running or wrong port | Start the app; verify port in settings |
| HTTP 403 | Secret mismatch | Enter the correct secret in the property inspector |
| Plugin not visible | Wrong install folder | Re-check the path and restart Stream Deck |
| Property inspector blank | WebSocket connection failed | Reload Stream Deck; check console with F12 in PI dev tools |
