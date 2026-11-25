extends SceneTree
## CI entry for gdsh_lib/data: exit 0 (pass) / 1 (fail). Not a *_test.gd, so `test` skips it.
##     godot --headless --path . --script res://addons/_lib/gdsh_lib/data/_export_ignore/test/run_headless.gd

const SUITES = [
	preload("res://addons/_lib/gdsh_lib/data/_export_ignore/test/data_test.gd"),
	preload("res://addons/_lib/gdsh_lib/data/_export_ignore/test/config_file_test.gd"),
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures = 0
	for suite in SUITES:
		var res = suite.run_tests()
		print("\n".join(res.output))
		failures += res.result
	quit(0 if failures == 0 else 1)
