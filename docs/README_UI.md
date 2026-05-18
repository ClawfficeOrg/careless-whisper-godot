# Careless Whisper — UI Component Reference

## HistoryPanel

`scenes/ui/history_panel.tscn` / `scripts/ui/history_panel.gd`

A scrollable panel that records every completed transcription with a local
timestamp and persists the list across app restarts.

### Usage

The panel is already instanced in `scenes/main.tscn`.  It wires itself to
`SignalBus.transcription_completed` automatically in `_ready()`.

To embed the panel in another scene:

```gdscript
# In a parent script — no extra wiring needed; the panel self-connects.
@onready var history: HistoryPanel = $HistoryPanel
```

To add an entry programmatically:

```gdscript
history.add_entry("Some transcription text")
```

To clear all entries:

```gdscript
history.clear()
```

### Signals

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `history_cleared` | — | Emitted after `clear()` is called |

`SignalBus.history_added(text: String, timestamp: String)` is emitted globally
each time a new entry is appended.

### Persistence

Entries are saved to `user://history.json` as a JSON array of
`{text, timestamp}` objects.  A maximum of **100** entries are kept; older
entries are dropped from the front when the limit is exceeded.

The file is written synchronously on each `add_entry` call.  On first run the
file does not exist and an empty history is shown.

### Manual Test

Open `scenes/test/history_panel_test.tscn` and press **F5**.

- **Add Fake Entry** — appends one short entry and scrolls to it.
- **Add Long Entry** — appends a long entry to test text-wrapping.
- **Add 10 Entries** — rapid-fires 10 entries to stress-test scroll behaviour.
- **Clear History** — calls `clear()` and resets the fake counter.

Verify after a clear + restart that the JSON file at `user://history.json`
is empty and no stale entries appear.

---

## HistoryEntry

`scenes/ui/history_entry.tscn` / `scripts/ui/history_entry.gd`

A single read-only row in the HistoryPanel.  Consists of a fixed-width
timestamp `Label` and a wrapping `RichTextLabel` for the transcription text.

### API

```gdscript
entry.set_data(text: String, timestamp: String) -> void
```

Only called internally by `HistoryPanel._append_entry_node()`.
