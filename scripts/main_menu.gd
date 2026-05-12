extends Control

@onready var continue_btn: Button = $Buttons/ContinueBtn
@onready var high_score_label: Label = $HighScoreLabel

func _ready() -> void:
	continue_btn.disabled = not SaveManager.has_save()
	if SaveManager.high_score > 0:
		high_score_label.text = "BEST: Wave %d" % SaveManager.high_score
	else:
		high_score_label.visible = false
	$Buttons/StartBtn.pressed.connect(_on_start_pressed)
	$Buttons/ContinueBtn.pressed.connect(_on_continue_pressed)
	$Buttons/CardsBtn.pressed.connect(_on_cards_pressed)
	$Buttons/OptionsBtn.pressed.connect(_on_options_pressed)

func _on_start_pressed() -> void:
	SaveManager.continue_mode = false
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_continue_pressed() -> void:
	SaveManager.continue_mode = true
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_cards_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/cards_screen.tscn")

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/options_screen.tscn")
