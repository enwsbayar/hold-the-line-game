extends Control

func _ready() -> void:
	$WaveLabel.text = "You reached Wave %d" % SaveManager.last_wave_reached
	$BestLabel.text = "BEST: Wave %d" % SaveManager.high_score
	$Buttons/RetryBtn.pressed.connect(_on_retry_pressed)
	$Buttons/MenuBtn.pressed.connect(_on_menu_pressed)

func _on_retry_pressed() -> void:
	SaveManager.continue_mode = false
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
