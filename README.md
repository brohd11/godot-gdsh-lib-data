# GDSh data

`data` converts data files between JSON, YAML and Godot binary (`FileAccess.store_var`) in
[GDSh](https://github.com/brohd11/godot-gdsh.git) consoles. No editor dependency, so the gdsh CLI bundles it.

```
data to_yaml config.json                  # writes config.yml beside it
data to_json settings.yml out/settings.json
data to_bin --ext=dat level.json          # writes level.dat
data to_json --from-bin save.dat          # binary input needs --from-bin
find .json | data to_yaml --overwrite     # one path per stdin line
```

JSON and YAML inputs are read by extension. A binary input's root must be a Dictionary or Array. An existing
output is kept unless `--overwrite`. In the editor, the FileSystem is rescanned after writing (`--no-scan` skips it).

## Loading

```gdscript
host.add_command_dir(preload("res://addons/_lib/gdsh_lib/data/cmd/manifest.gd").resource_path.get_base_dir())
```

`src/data_convert.gd` holds the read/write logic for other callers.
