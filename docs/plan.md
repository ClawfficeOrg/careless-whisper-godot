# Careless Whisper — Task Plan

_Authored: 2025-07-10_

Tasks are ordered by dependency — foundational wiring before features, features before
polish, polish before CI. Each task is intended to be a single focused unit of work
that can be planned, implemented, reviewed, and committed independently.

Format: `- [ ] \`task-N\`: description`
Completed tasks are marked `[x]` automatically by Ralph after each successful commit.

---

- [x] `task-1`: Wire OSController autoload in project.godot
- [x] `task-2`: Implement focus_window in os_controller.gd via InputInjector
- [x] `task-3`: Write InputInjector integration test scene and script
- [x] `task-4`: Expand settings dialog — hotkeys tab, startup behavior, theme selector
- [x] `task-5`: Add system tray icon with right-click menu (Windows and Linux)
- [x] `task-6`: MacroManager autoload with three sample voice-triggered macros
- [x] `task-7`: CommandDispatcher — expand patterns for macro triggers and window commands
- [x] `task-8`: StreamDeck HTTP integration — tiny HTTP server and five sample action handlers
- [x] `task-9`: StreamDeck plugin — companion .streamDeckPlugin scaffold with manifest
- [x] `task-10`: End-to-end transcription test scene (headless-capable)
- [x] `task-11`: Mic device hot-swap support — device change detection and reconnect
- [ ] `task-12`: Output history panel — scrollable list of past transcriptions with timestamps
- [ ] `task-13`: Hotword and push-to-talk toggle mode (hold vs tap-to-toggle)
- [ ] `task-14`: Model management UI improvements — size display, loaded indicator, delete confirm
- [ ] `task-15`: CI workflow — GitHub Actions build matrix for Windows whisper_cpp DLL
