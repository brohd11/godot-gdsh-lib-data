# GDSh data

`data` converts data files between JSON, YAML and Godot binary (`FileAccess.store_var`), and reads, writes and
checks Godot ConfigFiles, in [GDSh](https://github.com/brohd11/godot-gdsh.git) consoles. No editor dependency, so the gdsh CLI bundles it.

```
data to_yaml config.json                  # writes config.yml beside it
data to_json settings.yml out/settings.json
data to_bin --ext=dat level.json          # writes level.dat
data to_json --from-bin save.dat          # binary input needs --from-bin
find .json | data to_yaml --overwrite     # one path per stdin line
```

JSON and YAML inputs are read by extension. A binary input's root must be a Dictionary or Array. An existing
output is kept unless `--overwrite`. In the editor, the FileSystem is rescanned after writing (`--no-scan` skips it).

## ConfigFiles

```
data config_file get project.godot                           # the file as Godot parsed it
data config_file get --json project.godot application        # one section as JSON
data config_file get addons/my_plugin/plugin.cfg plugin version   # one value; a String prints bare
data config_file set settings.cfg audio volume 0.8           # a Godot literal, else a String
data config_file get a.cfg audio | data config_file set b.cfg audio   # a section from key=value lines
data config_file set --erase settings.cfg audio volume       # or a whole section without the key
data config_file check export_presets.cfg plugin.cfg         # ok, or the parse error with its line
```

Section and key arguments complete from the file. `set` creates a missing file and saves through `ConfigFile`, so
the file's comments are dropped and its layout normalised.

## Loading

```gdscript
host.add_command_dir(preload("res://addons/_lib/gdsh_lib/data/cmd/manifest.gd").resource_path.get_base_dir())
```

`src/data_convert.gd` holds the read/write logic for other callers, `src/config_data.gd` the ConfigFile views.
