extends Control

signal card_played(card_node, tile_pos)

const RARITY_TEXTURES = {
	CardData.Rarity.BRONZE:  "res://assets/bronze_card.png",
	CardData.Rarity.SILVER:  "res://assets/silver_card.png",
	CardData.Rarity.GOLD:    "res://assets/gold_card.png",
	CardData.Rarity.EMERALD: "res://assets/emerald_card.png",
	CardData.Rarity.DIAMOND: "res://assets/diamond_card.png",
}

static var any_dragging := false

var data: CardData
var _dragging := false
var _origin_parent: Node = null
var _origin_index: int = 0
var _tilemap: TileMapLayer = null
var _highlight_nodes: Array = []
var _hover_highlight: Polygon2D = null

@onready var card_bg: TextureRect = $CardBG
@onready var char_icon: TextureRect = $CharIcon
@onready var highlight: TextureRect = $Highlight
@onready var name_label: Label = $NameLabel

func setup(card_data: CardData, tilemap: TileMapLayer) -> void:
	data = card_data
	_tilemap = tilemap
	card_bg.texture = load(RARITY_TEXTURES[data.rarity])
	if data.card_type == CardData.CardType.WARRIOR and data.character_data:
		char_icon.texture = _get_first_frame(data.character_data.texture)
	elif data.card_type == CardData.CardType.PASSIVE and data.card_icon:
		char_icon.texture = data.card_icon
		char_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_label.text = data.card_name
	highlight.visible = false

func _get_first_frame(texture: Texture2D) -> AtlasTexture:
	if texture == null:
		return null
	var total: int = 12 if data.character_data.has_attack_anim else 8
	var fw: int = texture.get_width() / total
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, fw, texture.get_height())
	return atlas

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hand_node = get_tree().get_first_node_in_group("hand_node")
		var is_battle: bool = hand_node != null and hand_node.battle_active
		if event.pressed and not any_dragging and not is_battle:
			_start_drag()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _dragging:
			_end_drag()

func _start_drag() -> void:
	_dragging = true
	any_dragging = true
	_origin_parent = get_parent()
	_origin_index = get_index()
	var saved_pos := global_position
	var ui := get_tree().get_first_node_in_group("ui_layer")
	if ui:
		reparent(ui, false)
		global_position = saved_pos
	highlight.visible = true
	z_index = 100
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.12)
	tween.parallel().tween_property(self, "rotation_degrees", 6.0, 0.12)
	if data == null or data.card_type != CardData.CardType.PASSIVE:
		_show_tile_highlights()

func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	any_dragging = false
	highlight.visible = false
	_clear_tile_highlights()
	var tile := _get_hovered_tile()
	var is_passive := data != null and data.card_type == CardData.CardType.PASSIVE
	if tile != Vector2i(-999, -999) or is_passive:
		scale = Vector2.ONE
		rotation_degrees = 0.0
		_restore_to_hand()
		emit_signal("card_played", self, tile)
	else:
		_return_to_hand()

func _return_to_hand() -> void:
	var hand_pos := _get_hand_global_pos()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", hand_pos, 0.15)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.15)
	tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.15)
	await tween.finished
	_restore_to_hand()

func _restore_to_hand() -> void:
	if _origin_parent and is_instance_valid(_origin_parent):
		reparent(_origin_parent, false)
		_origin_parent.move_child(self, _origin_index)
	scale = Vector2.ONE
	rotation_degrees = 0.0
	z_index = 0

func _get_hand_global_pos() -> Vector2:
	if _origin_parent and is_instance_valid(_origin_parent):
		return _origin_parent.global_position
	return global_position

func _process(_delta: float) -> void:
	if _dragging:
		global_position = get_global_mouse_position() - size / 2
		_update_hover_highlight()

func _show_tile_highlights() -> void:
	if _tilemap == null:
		return
	var parent := _tilemap.get_parent()
	for tile in _tilemap.get_used_cells():
		if _tilemap.get_cell_source_id(tile) == -1:
			continue
		var tile_data := _tilemap.get_cell_tile_data(tile)
		if tile_data == null:
			continue
		var has_custom: Variant = tile_data.get_custom_data("player_zone")
		if typeof(has_custom) == TYPE_BOOL and has_custom:
			var poly := _make_diamond(Color(0.2, 1.0, 0.3, 0.35))
			poly.position = _tilemap.map_to_local(tile)
			poly.z_index = 1
			parent.add_child(poly)
			_highlight_nodes.append(poly)
	_hover_highlight = _make_diamond(Color(0.4, 1.0, 0.4, 0.75))
	_hover_highlight.visible = false
	_hover_highlight.z_index = 2
	parent.add_child(_hover_highlight)

func _clear_tile_highlights() -> void:
	for n in _highlight_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_highlight_nodes.clear()
	if _hover_highlight != null and is_instance_valid(_hover_highlight):
		_hover_highlight.queue_free()
	_hover_highlight = null

func _update_hover_highlight() -> void:
	if _hover_highlight == null or not is_instance_valid(_hover_highlight):
		return
	var tile := _get_hovered_tile()
	if tile != Vector2i(-999, -999):
		_hover_highlight.position = _tilemap.map_to_local(tile)
		_hover_highlight.visible = true
	else:
		_hover_highlight.visible = false

func _make_diamond(color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, -4), Vector2(8, 0), Vector2(0, 4), Vector2(-8, 0)
	])
	poly.color = color
	return poly

func _get_hovered_tile() -> Vector2i:
	if _tilemap == null:
		return Vector2i(-999, -999)
	var mouse := get_global_mouse_position()
	var local := _tilemap.to_local(mouse)
	var tile := _tilemap.local_to_map(local)
	if _tilemap.get_cell_source_id(tile) == -1:
		return Vector2i(-999, -999)
	var tile_data := _tilemap.get_cell_tile_data(tile)
	if tile_data == null:
		return Vector2i(-999, -999)
	# player_zone custom data varsa onu kullan, yoksa tüm tile'lara izin ver
	var has_custom: Variant = tile_data.get_custom_data("player_zone")
	if typeof(has_custom) == TYPE_BOOL:
		if has_custom:
			return tile
		return Vector2i(-999, -999)
	return tile
