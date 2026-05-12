extends Control
class_name CardsScreen

static var return_scene := "res://scenes/main_menu.tscn"

const RARITY_TEXTURES = {
	CardData.Rarity.BRONZE:  "res://assets/bronze_card.png",
	CardData.Rarity.SILVER:  "res://assets/silver_card.png",
	CardData.Rarity.GOLD:    "res://assets/gold_card.png",
	CardData.Rarity.EMERALD: "res://assets/emerald_card.png",
	CardData.Rarity.DIAMOND: "res://assets/diamond_card.png",
}

var _font: Font
var grid: GridContainer

@onready var scroll: ScrollContainer = $ScrollContainer

func _ready() -> void:
	$TopBar/BackBtn.pressed.connect(_on_back_pressed)
	_font = load("res://fonts/m3x6.ttf")

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	hbox.add_child(grid)
	scroll.add_child(hbox)

	_load_cards()

func _load_cards() -> void:
	var cards: Array[CardData] = []
	for i in range(1, 99):
		var p := "res://assets/card_data/card_%d.tres" % i
		if ResourceLoader.exists(p):
			var res := load(p) as CardData
			if res != null:
				cards.append(res)
		else:
			break
	var passives := ["bomb", "coin", "heart", "necklace", "skull", "sword", "tik", "x"]
	for name in passives:
		var p := "res://assets/card_data/passive_%s.tres" % name
		if ResourceLoader.exists(p):
			var res := load(p) as CardData
			if res != null:
				cards.append(res)
	cards.sort_custom(func(a: CardData, b: CardData) -> bool: return a.rarity < b.rarity)
	for c in cards:
		_add_card_entry(c)

func _add_card_entry(data: CardData) -> void:
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
		icon_tex = _get_first_frame(data.character_data)
	elif data.card_type == CardData.CardType.PASSIVE and data.card_icon != null:
		icon_tex = data.card_icon
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.anchor_top = 0.0
		icon.anchor_bottom = 0.0
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
	if _font:
		name_lbl.add_theme_font_override("font", _font)
	name_lbl.add_theme_font_size_override("font_size", 15)
	card.add_child(name_lbl)

	if data.card_type == CardData.CardType.WARRIOR and data.character_data != null:
		var cd := data.character_data
		var stats := Label.new()
		stats.text = "HP:%d ATK:%d DEF:%d\nSPD:%.1f MOV:%d" % [cd.max_hp, cd.atk, cd.def, cd.spd, cd.move_speed]
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.autowrap_mode = TextServer.AUTOWRAP_OFF
		stats.anchor_left = 0.0
		stats.anchor_right = 1.0
		stats.anchor_top = 1.0
		stats.anchor_bottom = 1.0
		stats.offset_top = -10.0
		stats.offset_bottom = 10.0
		if _font:
			stats.add_theme_font_override("font", _font)
		stats.add_theme_font_size_override("font_size", 13)
		card.add_child(stats)
	elif data.card_type == CardData.CardType.PASSIVE and data.description != "":
		var desc := Label.new()
		desc.text = data.description
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.anchor_left = 0.0
		desc.anchor_right = 1.0
		desc.anchor_top = 1.0
		desc.anchor_bottom = 1.0
		desc.offset_top = -12.0
		desc.offset_bottom = 8.0
		if _font:
			desc.add_theme_font_override("font", _font)
		desc.add_theme_font_size_override("font_size", 11)
		card.add_child(desc)

	margin.add_child(card)
	grid.add_child(margin)

func _get_first_frame(cd: CharacterData) -> AtlasTexture:
	if cd.texture == null:
		return null
	var total := 12 if cd.has_attack_anim else 8
	var fw := cd.texture.get_width() / total
	var atlas := AtlasTexture.new()
	atlas.atlas = cd.texture
	atlas.region = Rect2(0, 0, fw, cd.texture.get_height())
	return atlas

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(return_scene)
