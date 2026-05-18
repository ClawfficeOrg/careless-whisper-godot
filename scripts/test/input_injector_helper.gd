## input_injector_helper.gd
## Helper utilities for the InputInjector integration test.
## Provides assertion helpers and result formatting; keeps the main
## integration script focused on test logic.
extends RefCounted

## One test result entry.
class TestResult:
	var name: String = ""
	var passed: bool = false
	var message: String = ""

	func _init(test_name: String, ok: bool, msg: String) -> void:
		name = test_name
		passed = ok
		message = msg


## Run a boolean assertion and return a TestResult.
static func assert_true(test_name: String, condition: bool, reason: String) -> TestResult:
	return TestResult.new(test_name, condition, reason)


## Format an array of TestResult values into a human-readable summary string.
static func format_summary(results: Array) -> String:
	var passed: int = 0
	var failed: int = 0
	var lines: PackedStringArray = PackedStringArray()
	for entry in results:
		var result: TestResult = entry as TestResult
		if result == null:
			continue
		if result.passed:
			passed += 1
			lines.append("  ✓ %s" % result.name)
		else:
			failed += 1
			lines.append("  ✗ %s — %s" % [result.name, result.message])
	lines.append("")
	lines.append("Passed: %d  Failed: %d" % [passed, failed])
	return "\n".join(lines)


## Return true when the InputInjector GDExtension class is registered.
static func extension_available() -> bool:
	return ClassDB.class_exists("InputInjector")
