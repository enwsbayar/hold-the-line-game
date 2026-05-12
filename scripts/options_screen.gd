extends Control

@onready var fs_toggle: CheckButton = $FullscreenRow/FSToggle

func _ready() -> void:
	fs_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_toggle.toggled.connect(_on_fs_toggled)
	$BackBtn.pressed.connect(_on_back_pressed)

func _on_fs_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
