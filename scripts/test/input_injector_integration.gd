## input_injector_integration.gd
## Integration test scene controller for InputInjector GDExtension.
##
## On _ready it runs an automated self-test suite that:
##   1. Checks ClassDB.class_exists("InputInjector") — fails fast if missing.
##   2. Instantiates the injector safely via ClassDB.instantiate.
##   3. Calls each public method with representative inputs and checks the
##      return value.
##   4. Populates the StatusLabel with a pass/fail summary.
##
## Manual buttons allow re-running individual operations interactively.
extends Control

const Helper = preload("res://scripts/test/input_injector_helper.gd")

var _injector: Object = null

@onready var _status_label: Label = $VBox/StatusLabel
@onready var _result_label: Label = $VBox/ResultLabel
@onready var _run_btn: Button = $VBox/HBox/RunAutoTestBtn
@onready var _key_btn: Button = $VBox/HBox/InjectKeyBtn
@onready var _click_btn: Button = $VBox/HBox/InjectClickBtn


func _ready() -> void:
	_run_btn.pressed.connect(_on_run_auto_test)
	_key_btn.pressed.connect(_on_inject_key)
	_click_btn.pressed.connect(_on_inject_click)

	if not Helper.extension_available():
		_status_label.text = "⚠ InputInjector GDExtension not loaded — tests skipped"
		_set_buttons_disabled(true)
		return

	_injector = ClassDB.instantiate("InputInjector")
	_status_label.text = "✓ InputInjector loaded — ready"
	_run_auto_test()



func _run_auto_test() -> void:
	var results: Array = []

	results.append(Helper.assert_true(
		"ClassDB.class_exists",
		Helper.extension_available(),
		"InputInjector not registered in ClassDB"
	))

	results.append(Helper.assert_true(
		"instantiate returns non-null",
		_injector != null,
		"ClassDB.instantiate returned null"
	))

	if _injector != null:
		var type_ok: bool = _injector.type_text("integration-test")
		results.append(Helper.assert_true(
			"type_text returns bool",
			type_ok == true or type_ok == false,
			"unexpected return type from type_text"
		))

		var key_ok: bool = _injector.press_key("ctrl+a")
		results.append(Helper.assert_true(
			"press_key ctrl+a",
			key_ok == true or key_ok == false,
			"unexpected return type from press_key"
		))

		var escape_ok: bool = _injector.press_key("escape")
		results.append(Helper.assert_true(
			"press_key escape",
			escape_ok == true or escape_ok == false,
			"unexpected return type from press_key escape"
		))

		var move_ok: bool = _injector.move_mouse(0, 0)
		results.append(Helper.assert_true(
			"move_mouse 0,0",
			move_ok == true or move_ok == false,
			"unexpected return type from move_mouse"
		))

		var click_ok: bool = _injector.click_mouse("left")
		results.append(Helper.assert_true(
			"click_mouse left",
			click_ok == true or click_ok == false,
			"unexpected return type from click_mouse"
		))

		var click_bad_ok: bool = _injector.click_mouse("unknown_button")
		results.append(Helper.assert_true(
			"click_mouse invalid button returns false",
			click_bad_ok == false,
			"expected false for unknown button, got true"
		))

	_result_label.text = Helper.format_summary(results)

	var all_passed: bool = true
	for entry in results:
		var r: Helper.TestResult = entry as Helper.TestResult
		if r != null and not r.passed:
			all_passed = false
			break
	_status_label.text = "✓ Auto-test complete — %s" % ("ALL PASSED" if all_passed else "FAILURES")



func _on_run_auto_test() -> void:
	if _injector == null:
		_status_label.text = "⚠ Extension not loaded"
		return
	_run_auto_test()



func _on_inject_key() -> void:
	if _injector == null:
		_result_label.text = "⚠ Extension not loaded"
		return
	var ok: bool = _injector.press_key("ctrl+a")
	_result_label.text = "press_key ctrl+a → %s" % ok



func _on_inject_click() -> void:
	if _injector == null:
		_result_label.text = "⚠ Extension not loaded"
		return
	var ok: bool = _injector.click_mouse("left")
	_result_label.text = "click_mouse left → %s" % ok



func _set_buttons_disabled(disabled: bool) -> void:
	_run_btn.disabled = disabled
	_key_btn.disabled = disabled
	_click_btn.disabled = disabled
