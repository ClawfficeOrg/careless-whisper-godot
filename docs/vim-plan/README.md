# Careless Whisper — Vim-Like Voice Control: Development Plan

**Based on:** `docs/careless-whisper-research.md` (2026-03-27)
**Plan authored:** 2026
**Semantic versioning base:** `v0.x` (pre-release / feature build-out)

---

## Table of Contents

1. [Vision](#1-vision)
2. [Research Findings & Concerns](#2-research-findings--concerns)
3. [Architecture Overview](#3-architecture-overview)
4. [Versioned Release Plan](#4-versioned-release-plan)
5. [Settings Reference](#5-settings-reference)
6. [Open Questions](#6-open-questions)

---

## 1. Vision

Careless Whisper evolves from a dictation tool into a full voice-driven OS control
layer, modeled on Vim's modal philosophy:

| Mode | Voice Analogy | Purpose |
|------|---------------|---------|
| **Insert** | Dictate text | Keyboard-emulated text entry or clipboard paste |
| **Visual** | Select & shape | Cursor movement, selection, replacement, surrounding |
| **Command** | Control everything | Switch apps, click UI, run app-specific commands |

Layered on top of modes:

- **Whichkey overlay** — contextual HUD showing available commands (à la neovim-whichkey)
- **Whisbar** — Vomnibar-style searchable command palette, triggered by hotkey
- **BYOK AI** — LLM backend for intent resolution on ambiguous commands
- **MCP** — Model Context Protocol command sources (StreamDeck, tool servers, etc.)

---

## 2. Research Findings & Concerns

### 2.1 Confirmed Research

| Claim | Status | Notes |
|-------|--------|-------|
| Win32 `EnumWindows` / `GetForegroundWindow` | ✅ Accurate | Mature API, no issues |
| `active-win-pos-rs` v0.10 current | ✅ `0.10.1` is latest | April 2026 |
| Wayland: KDE only for active window | ✅ Confirmed | `kdotool` is KDE-specific |
| GNOME does not support `wlr-layer-shell` | ✅ Confirmed | Deliberate policy, not a gap |
| macOS requires Screen Recording + Accessibility permissions | ✅ Confirmed | Both needed |
| AT-SPI2 works across Wayland on Linux | ✅ Confirmed | Via D-Bus, compositor-agnostic |
| Windows UI Automation (UIA) | ✅ Accurate | Best external a11y option on Windows |
| `enigo` supports Windows | ✅ `0.6.1` current | Full support |

### 2.2 Corrections & Concerns

#### ⚠️ CRITICAL: `active-win-pos-rs` has no `list_windows` API

The research document assumes we can call `list_windows()` from `active-win-pos-rs`.
**This function does not exist.** The crate exposes only:
- `get_active_window() -> Result<ActiveWindow, ()>`
- `get_position() -> Result<WindowPosition, ()>`

**Impact:** Window enumeration (for the "select window" overlay) requires a separate
implementation. Options:
- **Windows:** Call `EnumWindows` directly via `windows-sys` crate
- **macOS:** Call `CGWindowListCopyWindowInfo` directly via `core-graphics` crate
- **Linux X11:** Call `XQueryTree` via `x11rb` or similar
- **Linux Wayland/KDE:** `kdotool search` CLI or `kwin-scripting` DBus API
- **Linux Wayland/GNOME:** No solution without a GNOME Shell extension

**Decision needed:** Build a custom `window_lister` module in the `os_control`
GDExtension rather than relying on `active-win-pos-rs` for this.

#### ⚠️ CRITICAL: `accesskit` cannot read external apps' UI

The research doc lists `accesskit` as a "cross-platform accessibility" dependency.
**This is incorrect for our use case.** `accesskit` is a *provider* library — it
helps apps expose their own accessibility tree to screen readers. It cannot read
another application's UI elements.

**Impact:** For external UI element reading we must call platform APIs directly:
- **Windows:** `IUIAutomation` COM interface via `uiautomation` Rust crate or raw COM
- **macOS:** `AXUIElementCopyAttributeValue` via `accessibility` Rust crate
- **Linux:** `AT-SPI2` D-Bus interfaces via `atspi` Rust crate

The `atspi` crate (async, D-Bus based) is the correct choice for Linux.

#### ⚠️ `enigo` Wayland is experimental / GNOME-hostile

The research suggests `enigo` for cross-platform input injection. Reality:
- **Windows:** ✅ Full support
- **Linux X11:** ✅ Full support (default `x11rb` feature)
- **Linux Wayland (KDE/Sway/wlroots):** ✅ `wayland` feature flag
- **Linux Wayland (GNOME):** ⚠️ Requires `libei` feature + GNOME 46+, still experimental
- **macOS:** ⚠️ Requires Accessibility permission, works but is sandboxed

**Recommendation:** Ship X11 + Windows first. Document GNOME Wayland as experimental,
requiring the `libei` feature build.

#### ⚠️ Overlay on GNOME Wayland: no good path exists

`wlr-layer-shell` / `gtk4-layer-shell` **do not work on GNOME**. GNOME has
deliberately not implemented this protocol. The only GNOME-native option is writing
a GNOME Shell extension (JavaScript running inside Mutter), which is a completely
separate codebase and runtime.

**Decision:** For v0.x, officially support overlays only on:
- Windows (winit / Win32 layered windows)
- macOS (NSPanel)
- Linux X11 (all DEs)
- Linux Wayland: KDE, Sway, Hyprland, wlroots compositors
- Linux Wayland GNOME: **not supported in overlay mode** — degrade gracefully to
  a regular always-on-top Godot window (less elegant but functional)

#### ⚠️ Firefox does not natively use CDP

The research doc lists "Chrome/Firefox via CDP" as if they share an API.
**Firefox's native protocols are Marionette and WebDriver BiDi.** Firefox has a
partial CDP shim (Remote Agent) for Puppeteer compat, but it is intentionally
incomplete and Mozilla has no plans to complete it.

**Impact:** Browser integration must be split:
- **Chrome/Chromium/Brave/Edge:** CDP on port 9222
- **Firefox:** WebDriver BiDi (or CDP shim for basic ops, with known gaps)

A unified `BrowserBridge` abstraction layer in GDScript can hide this behind a common
interface.

#### ⚠️ GDScript `window.title` dot notation — invalid

The research's GDScript example uses `active.title`. Per project rules, Dictionary
key access **must** use `active["title"]` or `active.get("title", "")`.
All GDScript examples in this plan use correct syntax.

### 2.3 Platform Support Matrix (Corrected)

| Feature | Windows | macOS | Linux X11 | Wayland (KDE/wlroots) | Wayland (GNOME) |
|---------|---------|-------|-----------|----------------------|-----------------|
| Active window | ✅ | ✅ | ✅ | ✅ KDE only | ❌ |
| List all windows | ✅ Win32 | ✅ CGWindow | ✅ XQueryTree | ⚠️ KDE-dbus | ❌ |
| Accessibility read | ✅ UIA | ✅ AXUIElement | ✅ AT-SPI2 | ✅ AT-SPI2 | ✅ AT-SPI2 |
| Input injection | ✅ enigo | ⚠️ perm | ✅ enigo/X11 | ⚠️ enigo+wayland feat | ⚠️ libei (exp) |
| Overlay window | ✅ | ✅ NSPanel | ✅ | ✅ layer-shell | ⚠️ Godot fallback |
| Click-through overlay | ✅ | ✅ | ✅ | ✅ | ⚠️ No |

---

## 3. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│  Godot 4.6 (GDScript)                                           │
│                                                                  │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │ ModeManager│  │CommandDispatch│  │    OverlayController   │  │
│  │ (new)      │  │ (extend)     │  │    (new)               │  │
│  └─────┬──────┘  └──────┬───────┘  └────────────────────────┘  │
│        │                │                                        │
│  ┌─────▼──────────────────────────────────────────────────────┐ │
│  │              SignalBus (extend with new signals)            │ │
│  └─────────────────────────────────────────────────────────────┘│
│        │                │                                        │
│  ┌─────▼──────┐  ┌──────▼──────────────────────────────────┐   │
│  │VimController│  │           AppBridgeManager              │   │
│  │ (extend)   │  │ BrowserBridge / VSCodeBridge / etc.     │   │
│  └────────────┘  └─────────────────────────────────────────┘   │
│                                                                  │
│  GDExtension Boundary                                           │
│  ═══════════════════════════════════════════════════════════    │
│                                                                  │
│  os_control (Rust GDExtension — existing, extend)               │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐   │
│  │WindowManager │  │InputInjector │  │  AccessibilityReader │   │
│  │(extend)      │  │(existing)    │  │  (new)               │   │
│  └──────────────┘  └──────────────┘  └─────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

**New GDScript autoloads / singletons:**

| Autoload | Purpose |
|----------|---------|
| `ModeManager` | Tracks current voice mode (insert/visual/command), PTT state |
| `OverlayController` | Whichkey HUD, Whisbar palette, window picker overlay |
| `AppBridgeManager` | Routes app-specific commands to the right bridge |
| `AIBackend` | BYOK AI intent resolution (OpenAI-compat / Anthropic / local) |
| `MCPClient` | MCP protocol command sources |

**New Rust modules (in `os_control` GDExtension):**

| Module | Purpose |
|--------|---------|
| `window_lister` | Enumerate all windows (replaces missing `list_windows` in active-win-pos-rs) |
| `accessibility_reader` | Read external app UI elements via platform a11y APIs |
| `overlay_window` | Platform overlay creation (replaces winit approach with simpler direct API) |

**Implementation note — Sneak / Two-letter hinting:**

The `OverlayController` will also be responsible for a "Sneak" style, two-letter
hinting mode (Vim-sneak / link-hint inspired). This mode places small two-character
labels adjacent to interactive UI elements discovered by the `accessibility_reader`
or OCR fallback. Labels are chosen from a configurable charset and emitted as
non-overlapping pairs so each interactive target has a short unique label.

Input methods supported:
- Keyboard: type the two characters sequentially (like `sneak`/`vimium` hinting).
- Voice: speak the two characters. To improve recognition reliability, the system
  supports a phonetic mapping (e.g. NATO alphabet or a simpler phonetic set) so
  users can say "alpha bravo" or "A B". The default is to enable phonetic mode,
  and use two-letter pairs to reduce homophone collisions.

Behavioral notes:
- Default action on selecting a hint is `click` (configurable per-app or per-bridge).
- The overlay aligns labels using the accessibility element bounding boxes; for apps
  lacking a11y trees, fall back to OCR-detected bounding boxes.
- A short timeout (configurable) dismisses the overlay if no selection is made.

**Implementation note — Game safety (anti-cheat):**

Overlays, input injection, and global hooks can be flagged by anti-cheat systems
in online games. To reduce the risk of false positives, Careless Whisper will
ship with an opt-in safety mechanism that is enabled by default:

- `OverlayController` and `ModeManager` will automatically suspend overlays, whichkey
  HUDs, and global keyboard hooks when a game is detected.
- Game detection is conservative by default: it triggers on fullscreen-exclusive
  windows and on processes matching a user-configurable known-game list.
- When suspended, voice-command processing continues in a restricted mode (no
  overlay draws, no synthetic input injection). Users can re-enable overlays per-game
  in advanced settings but the default is to stay off to avoid anti-cheat flags.

Detection sources considered:
- Active window fullscreen state (exclusive/fullscreen flag)
- Known process executable names (configurable list)
- Steam/Proton/Launcher heuristics (future)

This safety mode is ON by default. See Settings Reference for configurable keys.

---

## 4. Versioned Release Plan

### v0.1 — Modal Foundation
*"It speaks and it types"*

**Goal:** The three modes exist, PTT works, basic insert/visual/command dispatch works,
keyboard injection works on Windows + Linux X11.

**Scope:**

- [ ] `ModeManager` autoload — tracks `mode: String` in `["insert", "visual", "command"]`
- [ ] Extend `ConfigManager` with all new settings (see §5)
- [ ] PTT button binding (hold CapsLock = insert-PTT, Win+CapsLock = command mode on Windows)
- [ ] Extend `CommandDispatcher` with visual and command mode verb patterns
- [ ] Extend `VimController` to handle visual mode commands (select word, select line,
  go to line N, replace `<X>` with `<Y>`)
- [ ] Extend `InputInjector` (Rust) with `type_text`, `press_key`, `send_chord` — verified
  working on Windows (enigo 0.6.1) and Linux X11
- [ ] Active window detection wired to `ModeManager` (suppresses insert if no text
  focus detected)
- [ ] Basic status display in the main Godot UI showing current mode
- [ ] Settings placeholder UI for all new config keys

**Deliverable:** You can dictate text (insert mode), navigate/select (visual mode),
and the mode switch is PTT-driven.

**Platform targets:** Windows (primary), Linux X11

---

### v0.2 — Window & App Awareness
*"It knows where it is"*

**Goal:** Careless Whisper can see what's on screen and route commands to the right app.

**Scope:**

- [ ] `window_lister` Rust module — custom `EnumWindows` (Win32), `CGWindowListCopyWindowInfo`
  (macOS), `XQueryTree` (X11)
- [ ] Expose `list_windows() -> Array[Dictionary]` and `get_active_window() -> Dictionary`
  to GDScript through `WindowManager` GDExtension class
- [ ] Command mode verb: "switch to `<app>`" — fuzzy match against window list
- [ ] Command mode verb: "select window" (no arg) — triggers window picker overlay (v0.3)
  as a placeholder for now just lists in terminal
- [ ] `AppBridgeManager` autoload scaffold with app-type detection heuristic (check
  window `app_name` against known app names)
- [ ] Hotkey for command mode on Windows: Win+CapsLock (register via OS-level hook
  in `os_control` Rust extension)
- [ ] Config: `command.hotkey`, `command.ptt_key`
- [ ] macOS support: active window + list windows via CoreGraphics

**Deliverable:** "Switch to Firefox" works. "Select window" lists windows.

**Platform targets:** Windows, macOS, Linux X11

---

### v0.3 — Overlay System (Whichkey + Window Picker)
*"It shows you what you can say"*

**Goal:** HUD overlays for context-sensitive help and window selection.

**Scope:**

- [ ] `OverlayController` autoload
- [ ] **Window Picker overlay** — triggered by ambiguous "select window" command;
  each window gets a 2-3 letter label (like Vimium hints); say the label to focus
- [ ] **Whichkey HUD** — shows available commands for the current mode and detected
  app, fades in after configurable delay
- [ ] Platform overlay implementation:
  - Windows: Godot sub-window with `always_on_top + transparent + no_focus`
  - macOS: NSPanel via `os_control` Rust layer
  - Linux X11: `_NET_WM_STATE_ABOVE` + `_NET_WM_WINDOW_TYPE_DOCK` (existing `os_control`)
  - Linux Wayland (KDE/wlroots): `wlr-layer-shell` (add to `os_control` Rust)
  - Linux Wayland GNOME: Godot window fallback with `always_on_top` (no click-through)
- [ ] Config: `overlay.whichkey_delay_ms`, `overlay.opacity`, `overlay.position`,
  `overlay.hint_charset`
- [ ] **Whisbar** (Vomnibar) — searchable floating command palette, voice or keyboard
  triggered; shows all available commands for current app context
- [ ] **Sneak overlay** — two-letter hinting mode (Vim-sneak inspired). Places a two-character
  overlay adjacent to interactive UI elements (buttons, links, fields). Users can
  activate a target by saying the two letters (voice) or typing them (keyboard).
  The overlay uses the accessibility API for accurate placement and falls back to OCR
  when necessary. Two-letter hints are chosen to be phonetically distinct by default
  to improve voice recognition reliability.
- [ ] **Game-safe default** — overlay drawing and synthetic input are suspended when
  a game is detected (see Settings Reference). This default-on safety avoids
  triggering anti-cheat heuristics in fullscreen games.

**Deliverable:** Whichkey HUD appears when you pause. Whisbar opens on hotkey. Window
picker overlays the screen with letter hints. Sneak overlay allows low-effort
selection of UI elements via short two-letter labels.

**Platform targets:** Windows, macOS, Linux X11, Linux Wayland (KDE/Sway)
**Known gap:** GNOME Wayland overlay is window-fallback only (documented)

---

### v0.4 — App-Specific Bridges: Browser + VSCode
*"It talks to your apps"*

**Goal:** Deep integration with the two highest-value apps (VSCode and browsers).

**Scope:**

- [ ] **`BrowserBridge`** GDScript class:
  - Chrome/Chromium/Brave/Edge: CDP on `localhost:9222`
  - Firefox: WebDriver BiDi (primary) + CDP shim fallback
  - Verbs: "open tab", "close tab", "go to `<url>`", "click `<link text>`",
    "scroll down/up", "go back", "search `<query>`"
  - Vimium-style hint mode: emit `f` equivalent, read DOM for link hints
- [ ] **`VSCodeBridge`** GDScript class:
  - Communicate via `code --remote` or Language Server Protocol (LSP) where possible
  - Verbs: "save file", "format document", "go to definition", "find `<symbol>`",
    "open file `<name>`", "run build", "toggle terminal"
  - Fallback: keyboard shortcut injection (enigo)
- [ ] Grammar files for browser and VSCode (JSON command definitions loaded by
  `CommandDispatcher`)
- [ ] `AppBridgeManager` auto-detects active window and routes to correct bridge
- [ ] Config: `browser.cdp_port`, `browser.protocol` (cdp / webdriver-bidi),
  `vscode.use_lsp`, `vscode.binary_path`

**Deliverable:** "Open new tab" works in Chrome. "Save file" works in VSCode without
keyboard focus tricks.

**Platform targets:** All (bridges are protocol-level, OS-independent)

---

### v0.5 — Accessibility Reader (UI Automation)
*"It can see your buttons"*

**Goal:** Read UI elements from arbitrary apps using platform accessibility APIs,
enabling "click button `<name>`", "focus field `<name>`" universally.

**Scope:**

- [ ] `accessibility_reader` Rust module in `os_control`:
  - Windows: `IUIAutomation` via `uiautomation` crate or raw COM (windows-sys)
  - macOS: `AXUIElementCopyAttributeValue` via `accessibility` crate
  - Linux: `atspi` crate (async D-Bus AT-SPI2)
- [ ] Expose to GDScript: `get_focused_element() -> Dictionary`,
  `find_element_by_name(name: String) -> Dictionary`,
  `click_element(element_id: String) -> bool`,
  `list_interactive_elements() -> Array[Dictionary]`
- [ ] Visual mode verbs powered by a11y: "click `<button name>`", "focus `<field>`",
  "read page" (announce focused element text)
- [ ] OCR fallback scaffold (Tesseract via `tesseract-rs`) for apps with no a11y tree —
  stub only in this version, full in v0.7
- [ ] Config: `accessibility.enabled`, `accessibility.ocr_fallback`

**Deliverable:** "Click Submit" works in most native apps. "Focus username field" works.

**Platform targets:** Windows (UIA), Linux (AT-SPI2). macOS in v0.6.

---

### v0.6 — macOS Deep Support + Permissions Flow
*"It's a good Mac citizen"*

**Goal:** Full macOS feature parity and smooth permissions onboarding.

**Scope:**

- [ ] macOS Accessibility permission request flow (prompt on first use)
- [ ] macOS Screen Recording permission request flow
- [ ] `AXUIElement` accessibility reader implementation
- [ ] NSPanel overlay fully integrated
- [ ] macOS-specific hotkey (no Win key) — default to `Ctrl+CapsLock`
- [ ] Full `enigo` macOS input injection (with permission handling)
- [ ] macOS app bridge: AppleScript / ScriptingBridge fallback for apps without CDP/API
- [ ] Config: `macos.request_accessibility_on_start`, `macos.request_screen_recording_on_start`

**Deliverable:** Careless Whisper is fully functional on macOS with guided permission setup.

---

### v0.7 — BYOK AI + Intent Resolution
*"It understands what you mean"*

**Goal:** Ambiguous or complex commands are resolved by an LLM backend.

**Scope:**

- [ ] `AIBackend` autoload:
  - OpenAI-compatible API (OpenAI, local LM Studio, Ollama, llama.cpp server)
  - Anthropic API
  - Config-driven model selection and endpoint URL
- [ ] Intent resolution pipeline: raw transcription → command parser → (on fail) →
  AI intent resolver → structured command dict → dispatch
- [ ] AI-generated command grammar: describe current app context to LLM, ask it to
  classify the utterance
- [ ] "Replace all instances of `<X>` with `<Y>`" — AI parses the strings, visual mode
  serially replaces via a11y/injection
- [ ] Config: `ai.backend` (openai / anthropic / local), `ai.endpoint_url`,
  `ai.model`, `ai.api_key` (stored in OS keychain, not config file),
  `ai.intent_threshold` (confidence below which AI is consulted)
- [ ] API key stored via OS keychain (never written to `user://config.cfg`)

**Deliverable:** "Surround this paragraph with quotes and make it italic in markdown"
works because the AI parses the intent.

---

### v0.8 — MCP Command Sources
*"It plugs into everything"*

**Goal:** Commands can be sourced from MCP servers — StreamDeck, tool servers, etc.

**Scope:**

- [ ] `MCPClient` autoload — implements Model Context Protocol client
- [ ] MCP tool discovery: list available tools from connected MCP servers
- [ ] MCP tool invocation via voice command: "execute `<tool name>`"
- [ ] StreamDeck MCP bridge
- [ ] Whichkey HUD shows MCP tools as available commands in command mode
- [ ] Config: `mcp.servers` (Array of `{url, name, enabled}`)

**Deliverable:** A StreamDeck button can be triggered by voice. Custom MCP tools
appear in the command palette.

---

### v0.9 — OCR Fallback + Game / Electron Support
*"It sees what the APIs can't"*

**Goal:** Apps with no accessibility API (games, some Electron apps, kiosk UIs) get
basic support via OCR and image matching.

**Scope:**

- [ ] Full Tesseract integration (previously stubbed)
- [ ] Screen region capture via `os_control` Rust (platform screenshot APIs)
- [ ] OCR-based "read screen" command
- [ ] OCR-based element finding: locate button by text match in screenshot
- [ ] Image matching fallback for icon-only buttons
- [ ] Config: `ocr.enabled`, `ocr.language`, `ocr.confidence_threshold`

**Deliverable:** "Click Start Game" works in a game launcher even with no a11y tree.

---

### v1.0 — Stable Release
*"It's ready for daily use"*

**Goal:** All v0.x features polished, documented, and stable across Windows, macOS,
Linux X11, and Linux Wayland (KDE/Sway). GNOME Wayland officially documented as
partial-support.

**Scope:**

- [ ] Full settings UI for all config keys
- [ ] Onboarding wizard (platform detection → permission requests → model download)
- [ ] Plugin/grammar system: community can ship app-specific command grammars as
  JSON files dropped into `user://grammars/`
- [ ] Comprehensive documentation
- [ ] CI for Windows + Linux (macOS CI if GitHub Actions macOS runners available)
- [ ] All `push_warning` stubs replaced with real implementations or clearly documented gaps

---

## 5. Settings Reference

These keys will be added to `ConfigManager`'s `DEFAULTS` dictionary. They cover all
new features introduced across v0.1–v1.0. Settings marked `[placeholder]` are added
to `DEFAULTS` now but have no active effect until the relevant version ships.

### Mode / PTT Settings (`mode.*`)

| Key | Type | Default | Version | Notes |
|-----|------|---------|---------|-------|
| `mode.current` | `String` | `"insert"` | v0.1 | Active mode: insert/visual/command |
| `mode.ptt_key_insert` | `String` | `"CapsLock"` | v0.1 | Hold to PTT in insert mode |
| `mode.ptt_key_command` | `String` | `"Super+CapsLock"` | v0.1 | Hold or tap to enter command mode |
| `mode.ptt_key_visual` | `String` | `""` | v0.1 | Optional dedicated visual PTT |
| `mode.command_hotkey` | `String` | `"Super+CapsLock"` | v0.2 | OS-registered hotkey |
| `mode.insert_paste_on_release` | `bool` | `false` | v0.1 | Paste buffer instead of typing char-by-char |
| `mode.auto_detect_text_focus` | `bool` | `true` | v0.1 | Suppress insert if no text field focused |

### Command Mode (`command.*`)

| Key | Type | Default | Version | Notes |
|-----|------|---------|---------|-------|
| `command.prefix` | `String` | `""` | v0.1 | Optional spoken prefix before commands |
| `command.universal_copy` | `String` | `"Control+c"` | v0.1 | Chord for "copy" command |
| `command.universal_paste` | `String` | `"Control+v"` | v0.1 | Chord for "paste" command |
| `command.universal_cut` | `String` | `"Control+x"` | v0.1 | Chord for "cut" command |
| `command.universal_close` | `String` | `"Control+w"` | v0.1 | Chord for "close" command |
| `command.vim_scroll_lines` | `int` | `3` | v0.1 | Lines scrolled per "scroll down/up" |
| `command.sneak_enabled` | `bool` | `true` | v0.3 | Enable Sneak two-letter hint mode for command selection |
| `command.sneak_hint_length` | `int` | `2` | v0.3 | Number of characters per hint label (2 recommended for voice)
| `command.sneak_hint_charset` | `String` | `"asdfjkl;"` | v0.3 | Characters used to generate hint pairs; choose phonetic-friendly chars |
| `command.sneak_phonetic_mode` | `bool` | `true` | v0.3 | Map letters to a phonetic alphabet for clearer voice input (NATO or custom)
| `command.sneak_voice_prefix` | `String` | `""` | v0.3 | Optional spoken prefix to enter sneak mode (e.g. "hint")
| `command.sneak_default_action` | `String` | `"click"` | v0.3 | Action taken when hint selected: `click` / `focus` / `activate` |

### Overlay Settings (`overlay.*`)

| Key | Type | Default | Version | Notes |
|-----|------|---------|---------|-------|
| `overlay.whichkey_enabled` | `bool` | `true` | v0.3 | Show Whichkey HUD |
| `overlay.whichkey_delay_ms` | `int` | `800` | v0.3 | Delay before HUD appears |
| `overlay.opacity` | `float` | `0.85` | v0.3 | 0.0–1.0 |
| `overlay.position` | `String` | `"bottom-right"` | v0.3 | top-left/top-right/bottom-left/bottom-right/center |
| `overlay.hint_charset` | `String` | `"asdfjkl;"` | v0.3 | Characters for window/link hints |
| `overlay.whisbar_hotkey` | `String` | `"Super+Space"` | v0.3 | Whisbar (Vomnibar) open key |
| `overlay.font_size` | `int` | `14` | v0.3 | HUD font size |
| `overlay.sneak_opacity` | `float` | `0.95` | v0.3 | Opacity for sneak hint labels |
| `overlay.sneak_timeout_ms` | `int` | `4000` | v0.3 | Time before sneak overlay auto-dismisses (ms) |
| `overlay.disable_in_games` | `bool` | `true` | v0.3 | Auto-disable overlays and synthetic input when a game is detected (default ON to avoid anti-cheat)
| `overlay.game_detection_mode` | `String` | `"fullscreen_or_known_process"` | v0.3 | Detection: `fullscreen` / `process` / `fullscreen_or_known_process`
| `overlay.known_game_processes` | `String` | `""` | v0.3 | Comma-separated process names to treat as games (e.g. `csgo.exe,steam.exe`) |

### Window Management (`windows.*`)

| Key | Type | Default | Version | Notes |
|-----|------|---------|---------|-------|
| `windows.list_all_enabled` | `bool` | `true` | v0.2 | Enable window enumeration |
| `windows.fuzzy_match_threshold` | `float` | `0.6` | v0.2 | Fuzzy match confidence for "switch to" |
| `windows.exclude_patterns` | `String` | `""` | v0.2 | Comma-separated title substrings to exclude |

### App Bridges (`bridge.*`)

| Key | Type | Default | Version | Notes |
|-----|------|---------|---------|-------|
| `bridge.browser.cdp_port` | `int` | `9222` | v0.4 | Chrome DevTools Protocol port |
| `bridge.browser.protocol` | `String` | `"cdp"` | v0.4 | cdp or webdriver-bidi |
| `bridge.browser.firefox_port` | `int` | `4444` | v0.4 | WebDriver BiDi port for Firefox |
| `bridge.vscode.enabled` | `bool` | `true` | v0.4 | [placeholder] |
| `bridge.vscode.binary_path` | `String` | `"code"` | v0.4 | Path to `code` CLI |
| `bridge.vscode.use_lsp` | `bool` | `false` | v0.4 | [placeholder] Use LSP for deep integration |

### Accessibility (`accessibility.*`)

| Key | Type | Default | Version | Notes |
|-----|------|---------|---------|-------|
| `accessibility.enabled` | `bool` | `true` | v0.5 | [placeholder] Platform a11y reader |
| `accessibility.ocr_fallback` | `bool` | `false` | v0.5 | [placeholder] OCR when a11y unavailable |
| `accessibility.click_highlight_ms` | `int` | `300` | v0.5 | [placeholder] Visual flash on click target |

### AI Backend (`ai.*`)

| Key | Type | Default | Version | Notes |
|-----|------|---------|---------|-------|
| `ai.enabled` | `bool` | `false` | v0.7 | [placeholder] Enable AI intent resolution |
| `ai.backend` | `String` | `"openai"` | v0.7 | [placeholder] openai / anthropic / local |
| `ai.endpoint_url` | `String` | `""` | v0.7 | [placeholder] Custom API base URL |
| `ai.model` | `String` | `"gpt-4o-mini"` | v0.7 | [placeholder] Model name |
| `ai.intent_threshold` | `float` | `0.7` | v0.7 | [placeholder] Confidence cutoff |
| `ai.system_prompt` | `String` | `""` | v0.7 | [placeholder] Custom system prompt prefix |

> **Security note:** `ai.api_key` is intentionally omitted from `DEFAULTS`.
> API keys must be stored in the OS keychain and never written to `user://config.cfg`.

### MCP (`mcp.*`)

| Key | Type | Default | Version | Notes |
|-----|------|---------|---------|-------|
| `mcp.enabled` | `bool` | `false` | v0.8 | [placeholder] Enable MCP client |
| `mcp.servers` | `String` | `""` | v0.8 | [placeholder] JSON array of server configs |

### OCR (`ocr.*`)

| Key | Type | Default | Version | Notes |
|-----|------|---------|---------|-------|
| `ocr.enabled` | `bool` | `false` | v0.9 | [placeholder] Enable OCR fallback |
| `ocr.language` | `String` | `"eng"` | v0.9 | [placeholder] Tesseract language code |
| `ocr.confidence_threshold` | `float` | `0.75` | v0.9 | [placeholder] Min OCR match confidence |

### macOS (`macos.*`)

| Key | Type | Default | Version | Notes |
|-----|------|---------|---------|-------|
| `macos.request_accessibility_on_start` | `bool` | `true` | v0.6 | [placeholder] Prompt for a11y permission |
| `macos.request_screen_recording_on_start` | `bool` | `true` | v0.6 | [placeholder] Prompt for Screen Recording |

---

## 6. Open Questions

1. **GNOME Wayland window enumeration** — Is there appetite to write a GNOME Shell
   extension as a companion daemon? Or accept GNOME Wayland as "command mode
   unsupported"?

2. **PTT ergonomics on macOS** — `Super+CapsLock` doesn't map cleanly. Is
   `Ctrl+CapsLock` acceptable, or should we ship a configurable keybind picker UI
   in v0.1?

3. **`insert_paste_on_release` vs char-by-char** — Some apps don't respond correctly
   to clipboard paste (password fields, IDEs with autocomplete). We likely need both
   modes. Should this be per-app or a global toggle?

4. **AI API key storage** — `SecretService` (Linux), `Keychain` (macOS), `Windows
   Credential Manager`. The `keyring` Rust crate handles all three. Should this live
   in the `os_control` GDExtension or as a separate `keyring` GDExtension?

5. **Grammar files format** — JSON vs GDScript resource (`.tres`)? JSON is easier for
   community contributions; `.tres` integrates better with Godot's resource system.

6. **Firefox WebDriver BiDi** — Firefox requires the Marionette port (2828) to be
   enabled. Users must launch Firefox with `--marionette` or via an installed
   extension (Remote Control). Is this acceptable friction, or do we prioritize
   Chrome-only for v0.4?

7. **Multi-cursor "replace all" serial replacement** — The research notes serial
   replacement as the plan. Edge cases: overlapping matches, replacements that
   create new matches. Define behavior (left-to-right, no cascading) clearly before
   implementing.

8. **`VimController` hotkey registration** — Currently vim mode is app-internal
   (Godot receives the keypress). For OS-wide PTT we need the `os_control` Rust
   extension to register a low-level keyboard hook *before* Godot's event system
   sees the key, so CapsLock never types a capital letter into the active app.
   This is achievable on Windows (SetWindowsHookEx) and X11 (XGrabKey) but
   not on macOS without Accessibility permission.

9. **Game detection accuracy and policy** — How aggressive should the default game
   detection be? Conservative defaults are recommended (fullscreen + known process
   list) to minimize false positives that could disable overlays unintentionally.

