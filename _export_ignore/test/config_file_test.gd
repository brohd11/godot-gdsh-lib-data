extends RefCounted
## gdsh_lib/data: `data config_file get|set|check` through a gdsh Context, in a temp dir under
## fixtures/ that is removed afterwards.
##     godot --headless --path . --script res://addons/_lib/gdsh_lib/data/_export_ignore/test/run_headless.gd

const Sh = preload("res://addons/_lib/gdsh/_ns/gd_sh.gd")
const CMD = "res://addons/_lib/gdsh_lib/data/cmd"
const FIXTURES = "res://addons/_lib/gdsh_lib/data/_export_ignore/test/fixtures"
const ExitCode = Sh.CommandBase.ExitCode

const SAMPLE = """; comment
[plugin]
name="Demo"
version="0.2.3"

[audio]
volume=0.5
muted=false
"""

static var _failures:Array[String] = []
static var _passed := 0


static func run_tests() -> Dictionary:
	_failures = []
	_passed = 0
	var dir = FIXTURES.path_join("_tmp_cfg_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	_test_get(dir)
	_test_set(dir)
	_test_check(dir)
	_test_completion(dir)
	_remove(dir)
	var output:Array[String] = ["gdsh_lib data config_file: %d passed, %d failed" % [_passed, _failures.size()]]
	for failure in _failures:
		output.append("  FAIL  " + failure)
	return {"result": _failures.size(), "output": output}


static func _test_get(dir:String) -> void:
	var path = dir.path_join("demo.cfg")
	_write(path, SAMPLE)
	var ctx = _run("data config_file get " + path)
	_check("whole file", [ctx.exit_code, ctx.stdout], [ExitCode.OK, "[plugin]\nname=\"Demo\"\nversion=\"0.2.3\"\n\n[audio]\nvolume=0.5\nmuted=false\n"])
	ctx = _run("data config_file get %s audio" % path)
	_check("section lines", ctx.stdout, "volume=0.5\nmuted=false\n")
	ctx = _run("data config_file get %s plugin version" % path)
	_check("a String prints bare", ctx.stdout, "0.2.3\n")
	ctx = _run("data config_file get %s audio muted" % path)
	_check("other values print as literals", ctx.stdout, "false\n")
	ctx = _run("data config_file get --json " + path)
	_check("--json file", JSON.parse_string(ctx.stdout), {"plugin": {"name": "Demo", "version": "0.2.3"}, "audio": {"volume": 0.5, "muted": false}})
	ctx = _run("data config_file get --json %s plugin" % path)
	_check("--json section", JSON.parse_string(ctx.stdout), {"name": "Demo", "version": "0.2.3"})
	ctx = _run("data config_file get --json %s plugin name" % path)
	_check("--json value", ctx.stdout, "\"Demo\"\n")
	ctx = _run("data config_file get %s video" % path)
	_check("missing section", [ctx.exit_code, "No section [video]" in ctx.stderr], [ExitCode.FAIL, true])
	ctx = _run("data config_file get %s audio pan" % path)
	_check("missing key", [ctx.exit_code, "No key pan" in ctx.stderr], [ExitCode.FAIL, true])
	ctx = _run("data config_file get " + dir.path_join("missing.cfg"))
	_check("missing file", [ctx.exit_code, "doesn't exist" in ctx.stderr], [ExitCode.FAIL, true])


static func _test_set(dir:String) -> void:
	var path = dir.path_join("demo.cfg")
	var ctx = _run("data config_file set %s audio volume 12" % path)
	_check("set ok", [ctx.exit_code, ctx.stdout.begins_with("Set [audio] volume")], [ExitCode.OK, true])
	_check("int literal", typeof(_value(path, "audio", "volume")), TYPE_INT)
	_run("data config_file set %s audio pos 'Vector2(1, 2)'" % path)
	_check("Vector2 literal", _value(path, "audio", "pos"), Vector2(1, 2))
	_run("data config_file set %s audio label hello" % path)
	_check("bare word is a String", _value(path, "audio", "label"), "hello")
	_run("data config_file set %s audio code '\"12\"'" % path)
	_check("quoted literal forces a String", _value(path, "audio", "code"), "12")
	_check("other keys kept", _value(path, "plugin", "name"), "Demo")

	var copy = dir.path_join("nested/copy.cfg")
	ctx = _run("data config_file get %s audio | data config_file set %s audio" % [path, copy])
	_check("section from stdin creates the file", [ctx.exit_code, _value(copy, "audio", "pos"), _value(copy, "audio", "label")], [ExitCode.OK, Vector2(1, 2), "hello"])
	ctx = _run("data config_file set %s audio" % copy, "; note\n\nmuted = true\n")
	_check("stdin merges, skipping comments", [ctx.exit_code, _value(copy, "audio", "muted"), _value(copy, "audio", "label")], [ExitCode.OK, true, "hello"])
	ctx = _run("data config_file set %s audio" % copy, "no_equals\n")
	_check("bad stdin line", [ctx.exit_code, "Expected key=value" in ctx.stderr], [ExitCode.ERR, true])
	ctx = _run("data config_file set %s audio" % copy)
	_check("no value and no stdin", ctx.exit_code, ExitCode.ERR)
	ctx = _run("data config_file set %s audio volume" % copy)
	_check("key without value", [ctx.exit_code, "--erase" in ctx.stderr], [ExitCode.ERR, true])

	ctx = _run("data config_file set --erase %s audio label" % copy)
	_check("erase key", [ctx.exit_code, _has(copy, "audio", "label"), _has(copy, "audio", "pos")], [ExitCode.OK, false, true])
	ctx = _run("data config_file set --erase %s audio" % copy)
	_check("erase section", [ctx.exit_code, _has(copy, "audio")], [ExitCode.OK, false])
	ctx = _run("data config_file set --erase %s audio" % copy)
	_check("erase missing", [ctx.exit_code, "Nothing to erase" in ctx.stderr], [ExitCode.FAIL, true])
	ctx = _run("data config_file set --erase %s a b" % dir.path_join("none.cfg"))
	_check("erase in missing file", [ctx.exit_code, FileAccess.file_exists(dir.path_join("none.cfg"))], [ExitCode.FAIL, false])


static func _test_check(dir:String) -> void:
	var good = dir.path_join("demo.cfg")
	var bad = dir.path_join("bad.cfg")
	_write(bad, "[a]\nx=1\n[b\n")
	var ctx = _run("data config_file check " + good)
	_check("check ok", [ctx.exit_code, ctx.stdout], [ExitCode.OK, "ok: %s\n" % good])
	ctx = _run("data config_file check %s %s" % [good, bad])
	_check("check reports the bad one", [ctx.exit_code, "ok: " + good in ctx.stdout, "bad.cfg" in ctx.stderr], [ExitCode.FAIL, true, true])
	if Sh.CommandBase.ErrorCapture.supported():
		# Godot's own line number (it counts the unclosed tag's line as 2), so only its presence is checked.
		var regex = RegEx.create_from_string("Invalid config: .*bad\\.cfg:\\d+: ")
		_check("parse error has its line", regex.search(ctx.stderr) != null, true)
	ctx = _run("data config_file check", "%s\n%s\n" % [good, good])
	_check("stdin paths", [ctx.exit_code, ctx.stdout.count("ok: ")], [ExitCode.OK, 2])
	ctx = _run("data config_file check")
	_check("no input is ERR", ctx.exit_code, ExitCode.ERR)
	ctx = _run("data --help")
	_check("data lists config_file", "config_file" in ctx.stdout, true)


static func _test_completion(dir:String) -> void:
	var path = dir.path_join("demo.cfg")
	var session = Sh.Context.new()
	session.load(CMD, true)
	var sections = Sh.Completion.new("data config_file get %s " % path, session).get_completions()
	_check("sections complete", [sections.has("plugin"), sections.has("audio")], [true, true])
	var keys = Sh.Completion.new("data config_file set %s plugin " % path, session).get_completions()
	_check("keys complete", [keys.has("name"), keys.has("version"), keys.has("volume")], [true, true, false])


static func _value(path:String, section:String, key:String):
	var cfg = ConfigFile.new()
	cfg.load(path)
	return cfg.get_value(section, key)


static func _has(path:String, section:String, key := "") -> bool:
	var cfg = ConfigFile.new()
	cfg.load(path)
	return cfg.has_section(section) if key.is_empty() else cfg.has_section_key(section, key)


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
