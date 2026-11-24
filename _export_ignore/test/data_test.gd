extends RefCounted
## gdsh_lib/data: `data to_json|to_yaml|to_bin` through a gdsh Context, in a temp dir under fixtures/
## that is removed afterwards.
##     godot --headless --path . --script res://addons/_lib/gdsh_lib/data/_export_ignore/test/run_headless.gd

const Sh = preload("res://addons/_lib/gdsh/_ns/gd_sh.gd")
const DataConvert = preload("res://addons/_lib/gdsh_lib/data/src/data_convert.gd")
const CMD = "res://addons/_lib/gdsh_lib/data/cmd"
const FIXTURES = "res://addons/_lib/gdsh_lib/data/_export_ignore/test/fixtures"
const ExitCode = Sh.CommandBase.ExitCode

const SAMPLE = {"name": "level", "size": 3, "tags": ["a", "b"], "nested": {"on": true}}

static var _failures:Array[String] = []
static var _passed := 0


static func run_tests() -> Dictionary:
	_failures = []
	_passed = 0
	var dir = FIXTURES.path_join("_tmp_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	_test_round_trip(dir)
	_test_refusals(dir)
	_test_inputs(dir)
	_remove(dir)
	var output:Array[String] = ["gdsh_lib data: %d passed, %d failed" % [_passed, _failures.size()]]
	for failure in _failures:
		output.append("  FAIL  " + failure)
	return {"result": _failures.size(), "output": output}


## json -> yaml -> bin -> json keeps the data (JSON numbers come back as floats, so compare as JSON text).
static func _test_round_trip(dir:String) -> void:
	var source = dir.path_join("level.json")
	_write(source, JSON.stringify(SAMPLE))
	var ctx = _run("data to_yaml " + source)
	_check("to_yaml ok", [ctx.exit_code, ctx.stderr], [ExitCode.OK, ""])
	_check("to_yaml writes .yml beside", FileAccess.file_exists(dir.path_join("level.yml")), true)
	ctx = _run("data to_bin --ext=dat " + dir.path_join("level.yml"))
	_check("to_bin --ext", [ctx.exit_code, FileAccess.file_exists(dir.path_join("level.dat"))], [ExitCode.OK, true])
	var back = dir.path_join("back/level.json")
	ctx = _run("data to_json --from-bin %s %s" % [dir.path_join("level.dat"), back])
	_check("two-path form writes there", [ctx.exit_code, FileAccess.file_exists(back)], [ExitCode.OK, true])
	_check("round trip keeps data", JSON.stringify(DataConvert.read(back).get("data")), JSON.stringify(JSON.parse_string(JSON.stringify(SAMPLE))))
	ctx = _run("data to_bin " + source)
	_check("to_bin defaults to .bin", FileAccess.file_exists(dir.path_join("level.bin")), true)


static func _test_refusals(dir:String) -> void:
	var source = dir.path_join("level.json")
	var yml = dir.path_join("level.yml")
	var ctx = _run("data to_yaml " + source)
	_check("existing output refused", [ctx.exit_code, "--overwrite" in ctx.stderr], [ExitCode.FAIL, true])
	ctx = _run("data to_yaml --overwrite " + source)
	_check("--overwrite replaces", ctx.exit_code, ExitCode.OK)
	ctx = _run("data to_json %s %s" % [source, dir.path_join("copy.json")])
	_check("same format refused", [ctx.exit_code, "already json" in ctx.stderr], [ExitCode.FAIL, true])
	ctx = _run("data to_json %s %s" % [dir.path_join("level.dat"), dir.path_join("from_dat.json")])
	_check("binary needs --from-bin", [ctx.exit_code, "--from-bin" in ctx.stderr], [ExitCode.FAIL, true])
	var scalar = dir.path_join("scalar.dat")
	FileAccess.open(scalar, FileAccess.WRITE).store_var(42)
	ctx = _run("data to_json --from-bin " + scalar)
	_check("binary root must be a collection", [ctx.exit_code, "Dictionary or Array" in ctx.stderr], [ExitCode.FAIL, true])
	var bad = dir.path_join("bad.json")
	_write(bad, "{\"a\": ")
	ctx = _run("data to_yaml " + bad)
	_check("bad JSON reported", [ctx.exit_code, "Invalid JSON" in ctx.stderr, FileAccess.file_exists(dir.path_join("bad.yml"))], [ExitCode.FAIL, true, false])
	ctx = _run("data to_yaml " + dir.path_join("missing.json"))
	_check("missing input", [ctx.exit_code, "doesn't exist" in ctx.stderr], [ExitCode.FAIL, true])
	_check("yml untouched by refusals", FileAccess.file_exists(yml), true)


static func _test_inputs(dir:String) -> void:
	var a = dir.path_join("in/a.json")
	var b = dir.path_join("in/b.json")
	_write(a, "[1, 2]")
	_write(b, "{\"k\": \"v\"}")
	var ctx = _run("data to_yaml", "%s\n%s\n" % [a, b])
	_check("stdin paths", [ctx.exit_code, FileAccess.file_exists(dir.path_join("in/a.yml")), FileAccess.file_exists(dir.path_join("in/b.yml"))],
		[ExitCode.OK, true, true])
	ctx = _run("data to_yaml")
	_check("no input is ERR", ctx.exit_code, ExitCode.ERR)
	ctx = _run("data --help")
	_check("namespace lists subcommands", ["to_bin" in ctx.stdout, "to_json" in ctx.stdout, "to_yaml" in ctx.stdout], [true, true, true])


static func _run(text:String, stdin := "") -> Sh.Context:
	var parent = Sh.Context.new()
	parent.load(CMD, true)
	var ctx = Sh.Context.new_ctx("test", parent)
	ctx.stdin = stdin
	Sh.Execute.execute_command_multiline(text, ctx)
	return ctx


static func _write(path:String, text:String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(text)


static func _remove(dir:String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


static func _check(label:String, got, expected) -> void:
	if got == expected:
		_passed += 1
	else:
		_failures.append("%s (expected %s, got %s)" % [label, expected, got])
