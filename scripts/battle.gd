extends Node2D

@onready var map_container: Node2D = $MapContainer
@onready var characters_node: Node2D = $Characters
@onready var hand = $UI/Hand
@onready var wave_label: Label = $UI/WaveLabel
@onready var enemy_label: Label = $UI/EnemyLabel
@onready var cards_overlay: Control = $UI/CardsOverlay
@onready var overlay_scroll: ScrollContainer = $UI/CardsOverlay/OverlayScroll
@onready var wave_transition: Control = $UI/WaveTransition

var _overlay_built := false
var _overlay_font: Font

const CHARACTER_SCENE = preload("res://scenes/character.tscn")

var current_wave := 0
var _tilemap: TileMapLayer = null
var _map_mid_x: int = 0
var card_pool: Array[CardData] = []
var _wave_generator := WaveGenerator.new()
var _wave_in_progress := false

var player_bonuses := {"hp": 1.0, "atk": 1.0, "def": 1.0, "spd": 1.0}
var enemy_bonuses  := {"hp": 1.0, "atk": 1.0, "def": 1.0, "spd": 1.0}
const STAT_NAMES = ["hp", "atk", "def", "spd"]
const STAT_LABELS = {"hp": "HP", "atk": "ATK", "def": "DEF", "spd": "SPD"}

func _ready() -> void:
	load_new_map()
	_load_card_pool()
	hand.character_spawn_requested.connect(_on_character_spawn_requested)
	hand.fight_requested.connect(start_wave)
	hand.setup(card_pool, _tilemap)
	_overlay_font = load("res://fonts/m3x6.ttf")
	hand.passive_played.connect(_on_passive_played)
	$UI/TopButtons/CardsBtn.pressed.connect(_on_cards_btn_pressed)
	$UI/TopButtons/QuitBtn.pressed.connect(_on_quit_btn_pressed)
	$UI/CardsOverlay/OverlayTopBar/CloseBtn.pressed.connect(_on_overlay_close_pressed)
	_create_speed_buttons()
	if SaveManager.continue_mode and SaveManager.has_save():
		_load_save()
		SaveManager.continue_mode = false
	else:
		hand.deal_cards()
		_spawn_wave_enemies()
	wave_label.text = "Wave %d" % (current_wave + 1)

func _load_card_pool() -> void:
	var paths: Array[String] = []
	for i in range(1, 99):
		var p := "res://assets/card_data/card_%d.tres" % i
		if ResourceLoader.exists(p):
			paths.append(p)
		else:
			break
	var passives := ["bomb","coin","heart","necklace","skull","sword","tik","x"]
	for name in passives:
		var p := "res://assets/card_data/passive_%s.tres" % name
		if ResourceLoader.exists(p):
			paths.append(p)
	for p in paths:
		var res := load(p) as CardData
		if res != null:
			card_pool.append(res)

func load_new_map() -> void:
	for child in map_container.get_children():
		child.queue_free()
	var map_scene := MapManager.get_random_map()
	if map_scene == null:
		return
	var map := map_scene.instantiate()
	map_container.add_child(map)
	_tilemap = map.get_node("TileMapLayer")
	_calc_map_midpoint()

func _calc_map_midpoint() -> void:
	if _tilemap == null:
		return
	var cells := _tilemap.get_used_cells()
	var min_x := cells[0].x
	var max_x := cells[0].x
	for c in cells:
		if c.x < min_x: min_x = c.x
		if c.x > max_x: max_x = c.x
	_map_mid_x = int((min_x + max_x) / 2.0)

func _spawn_wave_enemies() -> void:
	var wave := _wave_generator.generate(current_wave)
	var spawn_tiles := _get_enemy_spawn_tiles()
	for i in wave.enemies.size():
		var data := wave.enemies[i]
		var tile := spawn_tiles[i % spawn_tiles.size()]
		spawn_enemy(data, tile, true)
	_update_enemy_count()

func start_wave() -> void:
	_wave_in_progress = true
	wave_label.text = "Wave %d" % (current_wave + 1)
	print("Wave %d başladı!" % (current_wave + 1))
	for c in get_tree().get_nodes_in_group("enemy_characters"):
		c.frozen = false
	for c in get_tree().get_nodes_in_group("player_characters"):
		c.frozen = false

func _get_player_zone_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if _tilemap == null:
		return tiles
	for cell in _tilemap.get_used_cells():
		if cell.x <= _map_mid_x:
			tiles.append(cell)
	return tiles

func _get_enemy_spawn_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if _tilemap == null:
		return tiles
	for cell in _tilemap.get_used_cells():
		if cell.x > _map_mid_x:
			tiles.append(cell)
	tiles.shuffle()
	return tiles

func spawn_player_character(data: CharacterData, tile: Vector2i, override_path: String = "") -> void:
	if _tilemap == null:
		return
	var c := CHARACTER_SCENE.instantiate()
	c.max_hp = data.max_hp
	c.atk = data.atk
	c.def = data.def
	c.spd = data.spd
	c.has_attack_anim = data.has_attack_anim
	c.frozen = not _wave_in_progress
	c.source_path = override_path if override_path != "" else data.resource_path
	characters_node.add_child(c)
	c.add_to_group("player_characters")
	c.setup(tile, true, _tilemap, data.texture)
	c.died.connect(_on_character_died)

func spawn_enemy(data: CharacterData, tile: Vector2i, start_frozen: bool = false) -> void:
	if _tilemap == null:
		return
	var c := CHARACTER_SCENE.instantiate()
	c.max_hp = data.max_hp
	c.atk = data.atk
	c.def = data.def
	c.spd = data.spd
	c.has_attack_anim = data.has_attack_anim
	c.frozen = start_frozen
	characters_node.add_child(c)
	c.add_to_group("enemy_characters")
	c.setup(tile, false, _tilemap, data.texture)
	c.died.connect(_on_character_died)

func _on_character_died(_character) -> void:
	await get_tree().process_frame
	_update_enemy_count()
	var players := get_tree().get_nodes_in_group("player_characters")
	var enemies := get_tree().get_nodes_in_group("enemy_characters")
	if players.is_empty():
		_game_over()
	elif enemies.is_empty() and _wave_in_progress:
		_wave_won()

func _update_enemy_count() -> void:
	var count := get_tree().get_nodes_in_group("enemy_characters").size()
	enemy_label.text = "ENEMIES: %d" % count

func _wave_won() -> void:
	_wave_in_progress = false
	current_wave += 1
	await _show_wave_transition()
	load_new_map()
	var player_tiles := _get_player_zone_tiles()
	player_tiles.shuffle()
	var idx := 0
	for c in get_tree().get_nodes_in_group("player_characters"):
		if is_instance_valid(c) and idx < player_tiles.size():
			c.call("reset_for_next_wave", _tilemap, player_tiles[idx])
			idx += 1
	hand.battle_active = false
	hand.update_tilemap(_tilemap)
	hand.deal_cards()
	_spawn_wave_enemies()
	_save_game()

func _show_wave_transition() -> void:
	var pct: float = current_wave * 0.01
	var p_stat: String = STAT_NAMES[randi() % STAT_NAMES.size()]
	var remaining := STAT_NAMES.filter(func(s): return s != p_stat)
	var e_stat: String = remaining[randi() % remaining.size()]
	player_bonuses[p_stat] *= 1.0 + pct
	enemy_bonuses[e_stat]  *= 1.0 + pct
	_apply_bonuses_to_players()
	_wave_generator.enemy_bonuses = enemy_bonuses

	var cleared_lbl: Label = wave_transition.get_node("ClearedLabel")
	var bonus_lbl: Label   = wave_transition.get_node("BonusInfo")
	var incoming_lbl: Label = wave_transition.get_node("IncomingLabel")

	cleared_lbl.text  = "WAVE %d CLEARED!" % current_wave
	bonus_lbl.text    = "YOU: +%d%% %s      ENEMY: +%d%% %s" % [
		current_wave, STAT_LABELS[p_stat], current_wave, STAT_LABELS[e_stat]]
	incoming_lbl.text = "WAVE %d INCOMING..." % (current_wave + 1)

	cleared_lbl.modulate  = Color.WHITE
	bonus_lbl.modulate    = Color(1, 1, 1, 0)
	incoming_lbl.modulate = Color(1, 1, 1, 0)
	cleared_lbl.scale     = Vector2(0.3, 0.3)
	incoming_lbl.scale    = Vector2(0.3, 0.3)
	wave_transition.visible = true

	var t := create_tween()
	t.tween_property(cleared_lbl, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.3)
	t.tween_property(bonus_lbl, "modulate", Color.WHITE, 0.2)
	t.tween_interval(0.9)
	t.tween_property(cleared_lbl,  "modulate", Color(1,1,1,0), 0.15)
	t.parallel().tween_property(bonus_lbl, "modulate", Color(1,1,1,0), 0.15)
	t.tween_property(incoming_lbl, "modulate", Color.WHITE, 0.175)
	t.parallel().tween_property(incoming_lbl, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.7)
	t.tween_property(wave_transition, "modulate", Color(1,1,1,0), 0.2)
	await t.finished
	wave_transition.visible = false
	wave_transition.modulate = Color.WHITE

func _apply_bonuses_to_players() -> void:
	for c in get_tree().get_nodes_in_group("player_characters"):
		if not is_instance_valid(c):
			continue
		c.max_hp = int(c.max_hp * player_bonuses["hp"] / max(player_bonuses["hp"] / (1.0 + current_wave * 0.01), 0.001))
		c.atk    = int(c.atk    * player_bonuses["atk"] / max(player_bonuses["atk"] / (1.0 + current_wave * 0.01), 0.001))
		c.def    = int(c.def    * player_bonuses["def"] / max(player_bonuses["def"] / (1.0 + current_wave * 0.01), 0.001))
		c.spd    = c.spd * player_bonuses["spd"] / max(player_bonuses["spd"] / (1.0 + current_wave * 0.01), 0.001)


func _on_character_spawn_requested(char_data: CharacterData, tile: Vector2i) -> void:
	spawn_player_character(char_data, tile)

func _save_game() -> void:
	var alive_chars: Array = []
	for c in get_tree().get_nodes_in_group("player_characters"):
		if not is_instance_valid(c):
			continue
		var path: String = c.get("source_path")
		if path == "":
			continue
		alive_chars.append({
			"data_path": path,
			"max_hp": c.max_hp,
			"atk": c.atk,
			"def": c.def,
			"spd": c.spd,
		})
	SaveManager.save_game({
		"current_wave": current_wave,
		"player_bonuses": player_bonuses,
		"enemy_bonuses": enemy_bonuses,
		"alive_characters": alive_chars,
	})

func _load_save() -> void:
	var data := SaveManager.load_game()
	current_wave = int(data.get("current_wave", 0))
	var pb = data.get("player_bonuses", {})
	var eb = data.get("enemy_bonuses", {})
	for k in STAT_NAMES:
		if pb.has(k): player_bonuses[k] = float(pb[k])
		if eb.has(k): enemy_bonuses[k] = float(eb[k])
	_wave_generator.enemy_bonuses = enemy_bonuses
	var player_tiles := _get_player_zone_tiles()
	player_tiles.shuffle()
	var idx := 0
	var chars_data: Array = data.get("alive_characters", [])
	for cd in chars_data:
		var path: String = cd.get("data_path", "")
		if path == "" or idx >= player_tiles.size():
			idx += 1
			continue
		var base := load(path) as CharacterData
		if base == null:
			idx += 1
			continue
		var scaled := CharacterData.new()
		scaled.texture = base.texture
		scaled.has_attack_anim = base.has_attack_anim
		scaled.max_hp = int(cd.get("max_hp", base.max_hp))
		scaled.atk = int(cd.get("atk", base.atk))
		scaled.def = int(cd.get("def", base.def))
		scaled.spd = float(cd.get("spd", base.spd))
		scaled.move_speed = base.move_speed
		spawn_player_character(scaled, player_tiles[idx], path)
		idx += 1
	hand.deal_cards()
	_spawn_wave_enemies()

func _on_passive_played(effect: CardData.PassiveEffect, _value: float) -> void:
	var players := get_tree().get_nodes_in_group("player_characters")
	var enemies := get_tree().get_nodes_in_group("enemy_characters")
	match effect:
		CardData.PassiveEffect.BOMB:
			for c in enemies:
				if is_instance_valid(c): c.call("take_damage", 10)
		CardData.PassiveEffect.COIN:
			for c in players:
				if not is_instance_valid(c): continue
				if randf() < 0.5:
					c.max_hp = int(c.max_hp * 1.05) + 1
				else:
					c.max_hp = max(1, int(c.max_hp * 0.95))
				c.hp = min(c.hp, c.max_hp)
				c.call("_update_hp_bar")
		CardData.PassiveEffect.HEART:
			for c in players:
				if not is_instance_valid(c): continue
				c.max_hp = max(c.max_hp + 1, int(c.max_hp * 1.02))
				c.call("_update_hp_bar")
		CardData.PassiveEffect.NATURE_NECKLACE:
			for c in players:
				if is_instance_valid(c): c.def += max(1, int(c.def * 0.1))
		CardData.PassiveEffect.SKULL:
			for c in players:
				if is_instance_valid(c): c.atk += max(1, int(c.atk * 0.1))
		CardData.PassiveEffect.SWORD:
			for c in players:
				if is_instance_valid(c): c.atk += 1
		CardData.PassiveEffect.TIK:
			hand.deal_extra_cards(2)
		CardData.PassiveEffect.X_MARK:
			var valid := enemies.filter(func(e): return is_instance_valid(e))
			if not valid.is_empty():
				valid[randi() % valid.size()].call("take_damage", 99999)

func _on_cards_btn_pressed() -> void:
	if not _overlay_built:
		_build_overlay_cards()
		_overlay_built = true
	cards_overlay.visible = true

func _on_overlay_close_pressed() -> void:
	cards_overlay.visible = false

func _create_speed_buttons() -> void:
	var font: Font = load("res://fonts/m3x6.ttf")
	var hbox := HBoxContainer.new()
	hbox.anchor_left   = 1.0
	hbox.anchor_top    = 1.0
	hbox.anchor_right  = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left   = -72.0
	hbox.offset_top    = -16.0
	hbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hbox.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	hbox.add_theme_constant_override("separation", 2)
	$UI.add_child(hbox)
	for speed in [1, 2, 4, 8]:
		var btn := Button.new()
		btn.text = "%dx" % speed
		btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 10)
		var s: int = speed
		btn.pressed.connect(func(): Engine.time_scale = float(s))
		hbox.add_child(btn)

func _on_quit_btn_pressed() -> void:
	Engine.time_scale = 1.0
	_game_over()

func _build_overlay_cards() -> void:
	const RARITY_TEXTURES = {
		CardData.Rarity.BRONZE:  "res://assets/bronze_card.png",
		CardData.Rarity.SILVER:  "res://assets/silver_card.png",
		CardData.Rarity.GOLD:    "res://assets/gold_card.png",
		CardData.Rarity.EMERALD: "res://assets/emerald_card.png",
		CardData.Rarity.DIAMOND: "res://assets/diamond_card.png",
	}
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	hbox.add_child(grid)
	overlay_scroll.add_child(hbox)

	var sorted := card_pool.duplicate()
	sorted.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rarity < b.rarity)

	for data: CardData in sorted:
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_right", 4)
		var card := Control.new()
		card.custom_minimum_size = Vector2(64, 110)
		var bg := TextureRect.new()
		bg.texture = load(RARITY_TEXTURES[data.rarity])
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		card.add_child(bg)
		var icon_tex: Texture2D = null
		if data.card_type == CardData.CardType.WARRIOR and data.character_data != null:
			var cd := data.character_data
			if cd.texture != null:
				var total := 12 if cd.has_attack_anim else 8
				var fw := cd.texture.get_width() / total
				var atlas := AtlasTexture.new()
				atlas.atlas = cd.texture
				atlas.region = Rect2(0, 0, fw, cd.texture.get_height())
				icon_tex = atlas
		elif data.card_type == CardData.CardType.PASSIVE and data.card_icon != null:
			icon_tex = data.card_icon
		if icon_tex != null:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.anchor_left = 0.5
			icon.anchor_right = 0.5
			icon.offset_left = -8.0
			icon.offset_right = 8.0
			icon.offset_top = 25.0
			icon.offset_bottom = 41.0
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			card.add_child(icon)
		var name_lbl := Label.new()
		name_lbl.text = data.card_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_lbl.clip_text = true
		name_lbl.anchor_left = 0.0
		name_lbl.anchor_right = 1.0
		name_lbl.anchor_top = 1.0
		name_lbl.anchor_bottom = 1.0
		name_lbl.offset_top = -32.0
		name_lbl.offset_bottom = -19.0
		if _overlay_font: name_lbl.add_theme_font_override("font", _overlay_font)
		name_lbl.add_theme_font_size_override("font_size", 15)
		card.add_child(name_lbl)
		if data.character_data != null:
			var cd := data.character_data
			var stats := Label.new()
			stats.text = "HP:%d ATK:%d DEF:%d" % [cd.max_hp, cd.atk, cd.def]
			stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stats.autowrap_mode = TextServer.AUTOWRAP_OFF
			stats.clip_text = true
			stats.anchor_left = 0.0
			stats.anchor_right = 1.0
			stats.anchor_top = 1.0
			stats.anchor_bottom = 1.0
			stats.offset_top = -9.0
			stats.offset_bottom = -2.0
			if _overlay_font: stats.add_theme_font_override("font", _overlay_font)
			stats.add_theme_font_size_override("font_size", 13)
			card.add_child(stats)
		margin.add_child(card)
		grid.add_child(margin)

func _game_over() -> void:
	Engine.time_scale = 1.0
	_wave_in_progress = false
	SaveManager.delete_save()
	SaveManager.last_wave_reached = current_wave + 1
	SaveManager.update_high_score(current_wave + 1)
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")
