extends Node

const MAP_FOLDER := "res://scenes/maps/"

var _map_paths: Array[String] = []
var _last_index := -1

func _ready() -> void:
	_scan_maps()

func _scan_maps() -> void:
	_map_paths.clear()
	for i in range(1, 99):
		var path := MAP_FOLDER + "map_%d.tscn" % i
		if ResourceLoader.exists(path):
			_map_paths.append(path)
		else:
			break

func get_random_map() -> PackedScene:
	if _map_paths.is_empty():
		push_error("MapManager: Hiç harita bulunamadı!")
		return null
	var index := _pick_random_index()
	_last_index = index
	return load(_map_paths[index])

func _pick_random_index() -> int:
	if _map_paths.size() == 1:
		return 0
	var available: Array[int] = []
	for i in _map_paths.size():
		if i != _last_index:
			available.append(i)
	return available[randi() % available.size()]

func get_map_count() -> int:
	return _map_paths.size()
