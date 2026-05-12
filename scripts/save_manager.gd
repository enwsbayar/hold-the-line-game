extends Node

const SAVE_PATH      := "user://save.json"
const HIGHSCORE_PATH := "user://highscore.json"

var continue_mode := false
var last_wave_reached: int = 0
var high_score: int = 0

func _ready() -> void:
	_load_high_score()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func update_high_score(wave: int) -> void:
	if wave > high_score:
		high_score = wave
		var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"high_score": high_score}))

func _load_high_score() -> void:
	if not FileAccess.file_exists(HIGHSCORE_PATH):
		return
	var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		high_score = int(parsed.get("high_score", 0))
