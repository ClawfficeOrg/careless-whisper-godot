# Manual Testing Loop — Task 15

## Issues Found & Root Cause Analysis

---

### 1. Opening window too small to house the config dialog
**Status:** Bug — `project.godot` sets viewport to 800×500. `config_dialog.tscn` is 620×520
(taller than the main window). `popup_centered()` opens it inside the viewport bounds
so it gets clipped.

**Root cause:** Main window height (500) < config dialog height (520) + any OS chrome.
Also `config_dialog.tscn` has no `initial_position` override so it inherits parent
viewport constraints.

**Fix:** Raise the main viewport height in `project.godot` to at least 600, and set
`config_dialog.tscn` → `initial_position = 4` (CENTER_SCREEN) so it pops as a
true OS-level window, not a child viewport popup. Also set a sensible
`min_size` on the config Window node so it can never be too small.

---

### 2. OS registration (launch on boot) not yet implemented
**Status:** Known placeholder — `_on_launch_on_boot_toggled` in `config_dialog.gd`
saves the config key but logs `"OS registration not yet implemented"` to console.

**Root cause:** Platform-specific startup registration (Windows `HKCU\Run`, Linux
`.desktop` autostart) has never been implemented. The checkbox and config key
(`startup.launch_on_boot`) exist but do nothing real.

**Fix (short-term):** Replace the `push_warning` stub with a proper TODO comment and
change the log to `push_warning` → `print` so it doesn't appear as a warning. Gate
the checkbox behind an `is_supported` check and show a tooltip like
"Not yet supported on this platform" so the user isn't confused.

**Fix (proper task):** Implement `OSController.register_autostart(enabled: bool)` in
the Rust GDExtension using the `auto-launch` crate (Windows/Linux/macOS), wire it to
the checkbox.

---

### 3. PTT and PTT Command buttons don't work / not configurable in config
**Status:** Bug — `CommandDispatcher` has a complete PTT state machine (`ptt_press`,
`ptt_release`, hold/toggle modes) and listens for the `push_to_talk` InputMap action.
But:
- `project.godot` defines `push_to_talk` with **zero events** bound to it, so the
  keyboard shortcut never fires.
- `main.gd` connects `record_button.button_down/up` directly for hold-to-record but
  **never connects `CommandDispatcher.push_to_talk_pressed/released`** to the actual
  audio recording flow. The PTT system and the mic recording are two separate,
  unconnected paths.
- The Config dialog → Hotkeys tab lets you *type a string* into a `LineEdit` for PTT
  keys, but nothing ever reads that string back and registers it as an InputMap action.

**Fix:**
1. In `config_dialog.gd` / `hotkeys_editor.gd`: when a PTT key is committed, call
   `InputMap.action_erase_events("push_to_talk")` and add an `InputEventKey` for the
   new key string so it actually fires.
2. In `main.gd`: connect `CommandDispatcher.push_to_talk_pressed` → `_on_record_start`
   and `CommandDispatcher.push_to_talk_released` → `_on_record_stop` so PTT drives
   the same recording path as the UI button.
3. Add a default key binding (e.g. CapsLock) to `push_to_talk` in `project.godot`.
4. Wire the PTT mode option (hold vs toggle) in the Config dialog Settings tab — a
   simple `OptionButton` reading/writing `ConfigManager.get/set_ptt_mode()`.

---

### 4. Vim mode button does nothing / can't test OS control
**Status:** Bug — `vim_mode_button.pressed` → `_on_vim_mode_toggled()` correctly
toggles `VimController.enabled` and updates the button text. **BUT:**
- `VimController` only acts on `CommandDispatcher.command_executed` signals, which
  only fire when a transcription is parsed as a command (e.g. "vim insert mode").
- On Windows the fallback is `xdotool` — which doesn't exist on Windows.
- The OS control GDExtension (`InputInjector`) *is* loaded (no error about it in
  the log), but `VimController.use_native_input` is hard-coded to `false` so it
  never uses the extension.
- There is no visual feedback when vim mode is on (no status label update, no
  overlay, nothing changes in the UI beyond the button text).

**Fix:**
1. Set `VimController.use_native_input = true` when `ClassDB.class_exists("InputInjector")`
   — do this in `VimController._ready()` or `main.gd` after wiring the whisper node.
2. Add a quick smoke-test: when vim mode is toggled ON, immediately try
   `OSController.get_active_window()` and print the result to `status_label` so the
   user can see OS control is working.
3. The whisper node doesn't have `type_text`/`press_key` — those live on
   `OSController.input_injector`. Fix `VimController._type_text` /`_press_key` to call
   `OSController.type_text()` / `OSController.press_key()` instead of
   `_whisper_node.type_text()`.

---

### 5. No vim mode overlay for quick letter jumps
**Status:** Missing feature — there is no overlay implementation anywhere.
`config_manager.gd` has placeholder keys (`overlay.whichkey_enabled`,
`overlay.hint_charset`, etc.) but there is no scene, script, or node for it.

**Fix (proper task):** This is a significant feature (a which-key-style letter-hint
overlay). It deserves its own task. Create a `task-16` for it:
- New `scenes/ui/whichkey_overlay.tscn` — a full-screen transparent `CanvasLayer`
  with `Label` hints positioned over focusable UI targets.
- `scripts/ui/whichkey_overlay.gd` — reads `overlay.hint_charset` from config,
  shows on a configurable hotkey, hides on Escape or letter press.
- Wire into `VimController` so it shows when vim mode is active and a command hotkey
  is held.

---

### 6. Pretty ugly
**Status:** UX debt — no theming applied beyond a background `ColorRect`. No font,
no spacing rhythm, no icon, default Godot control styling.

**Fix (proper task):** Create a `task-17` for UI polish:
- Load a custom `Theme` resource (a `.tres` file) on the root `Control` in `main.tscn`.
- Set a consistent font (e.g. bundle Inter or use system default), accent color, and
  panel/button styles.
- Review and tighten up margins and minimum sizes across main and config scenes.

---

### 7. Duplicate model selector / double load / no completion indicator
**Status:** Three separate sub-bugs:

**7a. Two model selectors:**
The old inline `ConfigDialog` in `main.tscn` had its own Settings tab with a
`ModelPathEdit` + `BrowseButton`. The new `config_dialog.tscn` also has a Settings
tab with `ModelPathEdit` + `BrowseButton` AND a full Models tab with the model browser.
Now that `main.tscn` uses the instanced `config_dialog.tscn`, the inline duplicate is
gone — but `config_dialog.gd` still has both: a manual path entry (Settings tab) and
the model browser (Models tab). Clicking "Load" in the model browser calls
`_on_model_browser_load(path)` which sets `model_path_edit.text` and then calls
`_on_load_model()`. This is intentionally dual-path, not a bug — but the UX is
confusing.

**Fix:** The Settings tab's manual path row (`ModelPathEdit` + `BrowseButton` +
`LoadModelButton`) should be **removed** now that the dedicated Models tab exists.
Keep only the model browser as the single model selection surface.

**7b. Double load:**
`main.gd._autoload_model()` calls `whisper.load_model(saved_path)` on startup.
Then if the user opens Config and clicks Load again, `config_dialog._invoke_load_model_main()`
calls `whisper.load_model(path)` a second time. The WhisperCpp extension's
`model_loaded` signal fires, which causes `main.gd` to emit `SignalBus.model_ready`
*and* `config_dialog._invoke_load_model_main` also calls `_finish_model_load` which
emits `SignalBus.model_ready` again — so the signal fires twice.

**Fix:** In `_invoke_load_model_main`, don't call `_finish_model_load` synchronously.
The extension already emits `model_loaded` asynchronously (non-blocking). Connect
`whisper.model_loaded` → `_finish_model_load` once in `_ready` (with a one-shot
disconnect after first call), and let the signal be the sole trigger. Remove the
synchronous `if success: _finish_model_load(...)` call.

**7c. No completion indicator:**
`_finish_model_load` emits `SignalBus.model_ready` which `main.gd._on_model_ready`
handles — it sets `status_label.text = "Model ready: ..."` and calls
`loading_overlay.hide_loading()`. This *should* work. The problem is the double-emit
(7b) races with the overlay: the first emit hides the overlay, the second re-fires
`_on_model_ready` after the state is already updated, making it look like it worked
but the label flickers.

Also: the load button re-enable (`load_button.disabled = false`, `load_button.text = "Load Model"`)
happens in `_finish_model_load` which is triggered by the `config_dialog` path — but
if the user loaded from `_autoload_model()` on startup, `_finish_model_load` is never
called at all (that path only calls `whisper.load_model` directly), so the status
label never gets a "Model ready" confirmation from startup autoload.

**Fix:** Connect `whisper.model_loaded` in `main.gd` to also update `_model_loaded = true`
and `model_label` — which it already does via `SignalBus.model_ready`. The gap is
`_autoload_model` starts the load but the `model_loaded` signal from the extension
feeds back through `main.gd` → `SignalBus.model_ready` → `_on_model_ready`. That
should already work. The double-load fix in 7b will clean up the confusion.

---

## Prioritised Fix Tasks

| Priority | Issue | Effort | Notes |
|---|---|---|---|
| P0 | 3 — PTT key binding registration | Small | InputMap wiring, 1-day job |
| P0 | 3 — PTT → recording bridge in main.gd | Tiny | 3 lines |
| P0 | 4 — VimController uses OSController not whisper node | Tiny | 2 lines |
| P0 | 4 — `use_native_input` auto-detect on Windows | Tiny | 1 line in `_ready` |
| P1 | 7b — double model_loaded signal | Small | refactor signal wiring |
| P1 | 7a — remove duplicate model path row from Settings tab | Small | scene + script edit |
| P1 | 1 — main window height + config dialog initial_position | Tiny | project.godot + tscn |
| P2 | 2 — launch on boot stub UX | Tiny | tooltip + disable |
| P3 | 5 — whichkey overlay | Large | new task-16 |
| P3 | 6 — UI polish | Medium | new task-17 |
