## tray_manager.gd
## TrayManager — System tray icon with right-click menu for Windows and Linux.
##
## Uses a native SystemTray GDExtension class when available; falls back to a
## no-op placeholder so the rest of the application continues to function.
##
## Public API
## ----------
##   TrayManager.set_icon(texture: Texture2D) -> void
##   TrayManager.set_tooltip(text: String) -> void
##   TrayManager.set_menu(items: Array[Dictionary]) -> void
##     Each item dict: { "id": String, "label": String, "enabled": bool (optional) }
##   TrayManager.show_tray() -> void
##   TrayManager.hide_tray() -> void
##   TrayManager.is_available() -> bool
##
## Signals
## -------
##   tray_menu_selected(item_id: String)   — user picked a menu entry
##   tray_icon_activated()                 — user left-clicked the tray icon
extends Node


signal tray_menu_selected(item_id: String)
signal tray_icon_activated()

## Default menu items shown when no explicit menu has been set.
const DEFAULT_MENU: Array[Dictionary] = [
	{"id": "open", "label": "Open Careless Whisper", "enabled": true},
	{"id": "settings", "label": "Settings…", "enabled": true},
	{"id": "quit", "label": "Quit", "enabled": true},
]

## The native SystemTray object from the GDExtension (null when not available).
var _tray: Object = null

## Whether the native SystemTray class was found at startup.
var _native_available: bool = false

## Current menu items (Array[Dictionary]).
var _menu_items: Array[Dictionary] = []


func _ready() -> void:
	if ClassDB.class_exists("SystemTray"):
		_tray = ClassDB.instantiate("SystemTray")
		if _tray != null:
			_native_available = true
			_connect_native_signals()
		else:
			push_warning("[TrayManager] ClassDB.instantiate('SystemTray') returned null")
	else:
		push_warning("[TrayManager] SystemTray GDExtension not loaded — tray unavailable")

	set_menu(DEFAULT_MENU)


## Returns true when the native SystemTray extension is loaded and functional.
func is_available() -> bool:
	return _native_available and _tray != null


## Set the tray icon.
func set_icon(texture: Texture2D) -> void:
	if not is_available():
		return
	if _tray.has_method("set_icon"):
		_tray.set_icon(texture)


## Set the tooltip text shown on hover.
func set_tooltip(text: String) -> void:
	if not is_available():
		return
	if _tray.has_method("set_tooltip"):
		_tray.set_tooltip(text)


## Replace the context-menu with a new list of items.
##
## Each dict must contain:
##   "id"      : String — unique identifier emitted with tray_menu_selected
##   "label"   : String — visible text in the menu
##   "enabled" : bool   — (optional, defaults to true) whether the item is clickable
func set_menu(items: Array[Dictionary]) -> void:
	_menu_items = items.duplicate(true)
	if not is_available():
		return
	if _tray.has_method("set_menu"):
		_tray.set_menu(_menu_items)


## Show the tray icon.
func show_tray() -> void:
	if not is_available():
		return
	if _tray.has_method("show"):
		_tray.show()


## Hide the tray icon without destroying it.
func hide_tray() -> void:
	if not is_available():
		return
	if _tray.has_method("hide"):
		_tray.hide()


## Return a copy of the current menu items.
func get_menu_items() -> Array[Dictionary]:
	return _menu_items.duplicate(true)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


func _connect_native_signals() -> void:
	if _tray.has_signal("menu_item_selected"):
		_tray.menu_item_selected.connect(Callable(self, "_on_native_menu_item_selected"))
	if _tray.has_signal("icon_activated"):
		_tray.icon_activated.connect(Callable(self, "_on_native_icon_activated"))


func _on_native_menu_item_selected(item_id: String) -> void:
	tray_menu_selected.emit(item_id)
	SignalBus.tray_menu_selected.emit(item_id)
	_handle_default_actions(item_id)


func _on_native_icon_activated() -> void:
	tray_icon_activated.emit()


func _handle_default_actions(item_id: String) -> void:
	if item_id == "quit":
		SignalBus.app_quitting.emit()
		get_tree().quit()
	elif item_id == "open":
		_restore_main_window()


func _restore_main_window() -> void:
	var window: Window = get_tree().get_root()
	window.show()
	window.move_to_foreground()
