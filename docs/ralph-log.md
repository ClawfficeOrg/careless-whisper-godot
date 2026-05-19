
## 2026-05-18 03:55

DONE: task-1 — commit 459e477 pushed on task-1. Premium calls this session: 1.

## 2026-05-18 04:06

DONE: task-2 — commit 06450c4 pushed on task-2. Premium calls this session: 2.

## 2026-05-18 04:20

DONE: task-3 — commit f795b52 pushed on task-3. Premium calls this session: 4.

## 2026-05-18 04:28

DONE: task-4 — commit bde21f8 pushed on task-4. Premium calls this session: 5.

## 2026-05-18 04:33

DONE: task-5 — commit d9000f6 pushed on task-5. Premium calls this session: 6.

## 2026-05-18 04:37

DONE: task-6 — commit bf54e42 pushed on task-6. Premium calls this session: 7.

## 2026-05-18 04:45

DONE: task-7 — commit 949eac8 pushed on task-7. Premium calls this session: 8.

## 2026-05-18 04:52

DONE: task-8 — commit e626fe6 pushed on task-8. Premium calls this session: 9.

## 2026-05-18 04:57

DONE: task-9 — commit ff558c7 pushed on task-9. Premium calls this session: 10.

## 2026-05-18 05:03

DONE: task-10 — commit 6c7430d pushed on task-10. Premium calls this session: 11.

## 2026-05-18 05:15

DONE: task-11 — commit deea88c pushed on task-11. Premium calls this session: 12.

## 2026-05-18 05:23

DONE: task-12 — commit 35cb0b7 pushed on task-12. Premium calls this session: 13.

## 2026-05-18 05:28

DONE: task-13 — commit 021dba0 pushed on task-13. Premium calls this session: 14.

## 2026-05-18 05:39

DONE: task-14 — commit aac3883 pushed on task-14. Premium calls this session: 15.

## 2026-05-18 05:43

BLOCKED: task-15 — requires repo secrets and human confirmation. Branch: task-15.


## 2026-05-18 05:44

DONE: task-15 — commit f0d9ef0 pushed on task-15. Premium calls this session: 16.

## 2026-05-18 05:44

Session ended: all tasks complete. Tasks: 16. Premium requests: 16.

## Manual testing loop — task-15 bugs fixed (commit 2d2b6d5)

During manual testing on task-15 branch the following bugs were found and fixed:

- FIXED: os_controller.gd had `class_name OSController` which shadowed the autoload
  singleton — root cause of parse errors in mic_manager, test scripts, and the
  Node not found errors in model_browser.gd.
- FIXED: config_dialog.gd used `.pressed` (a signal) instead of `.button_pressed`
  to set the launch-on-boot checkbox state.
- FIXED: scenes/main.tscn had a stale hand-written inline ConfigDialog subtree that
  lacked ScrollContainer/ModelListBox and DeleteConfirmDialog. Replaced with an
  instance of config_dialog.tscn.
- FIXED: PTT system was fully orphaned — CommandDispatcher.push_to_talk_pressed/
  released were never connected to the audio recording path. Connected in main.gd.
- FIXED: push_to_talk InputMap action had zero events bound. Default: CapsLock.
  push_to_talk_command action added.
- FIXED: hotkeys_editor.gd saved key strings to config but never called InputMap
  to register them. Now calls action_erase_events + action_add_event on commit.
- FIXED: VimController._type_text/_press_key called _whisper_node.type_text/press_key
  (methods that don't exist there). Rerouted through OSController.type_text/press_key.
- FIXED: VimController.use_native_input was hard-coded false. Now auto-detects
  ClassDB.class_exists("InputInjector") in _ready().
- FIXED: config_dialog._invoke_load_model_main called _finish_model_load synchronously
  on success AND the async model_loaded signal also fired it — double emit of
  SignalBus.model_ready. Now uses CONNECT_ONE_SHOT on model_loaded only.
- FIXED: config_dialog Settings tab had a duplicate ModelPathEdit/BrowseButton/
  LoadModelButton row alongside the Models tab browser. Removed the duplicate.
- IMPROVED: config dialog opens with initial_position = 4 (CENTER_SCREEN).
- IMPROVED: main viewport raised to 820x620 (was 800x500, smaller than the dialog).
- IMPROVED: PTT mode dropdown (Hold/Toggle) added to Settings tab.

New tasks identified and added to plan.md:
- task-16: whichkey overlay for vim mode letter-jump hints
- task-17: UI polish — custom Theme resource, fonts, spacing
