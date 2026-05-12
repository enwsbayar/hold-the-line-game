extends HBoxContainer

signal character_spawn_requested(char_data, tile_pos)
signal fight_requested
signal passive_played(effect, value)

const CARD_SCENE = preload("res://scenes/card.tscn")
const CARDS_PER_TURN := 3
const CARDS_FIRST_WAVE := 4

var _card_pool: Array[CardData] = []
var _tilemap: TileMapLayer = null

func setup(pool: Array[CardData], tilemap: TileMapLayer) -> void:
	_card_pool = pool
	_tilemap = tilemap
	_first_deal = true

func update_tilemap(tilemap: TileMapLayer) -> void:
	_tilemap = tilemap
	for card in get_children():
		card._tilemap = tilemap

var _first_deal := true
var battle_active := false

func deal_cards() -> void:
	var target := CARDS_FIRST_WAVE if _first_deal else CARDS_PER_TURN
	_first_deal = false
	var count := target - get_child_count()
	for i in count:
		_add_random_card()

func _add_random_card() -> void:
	if _card_pool.is_empty():
		return
	var data: CardData = _weighted_pick()
	var card := CARD_SCENE.instantiate()
	add_child(card)
	card.setup(data, _tilemap)
	card.card_played.connect(_on_card_played)

func _weighted_pick() -> CardData:
	var total := 0.0
	for c in _card_pool:
		total += c.weight
	var roll := randf() * total
	var cumulative := 0.0
	for c in _card_pool:
		cumulative += c.weight
		if roll <= cumulative:
			return c
	return _card_pool[-1]

func deal_extra_cards(count: int) -> void:
	for i in count:
		_add_random_card()

func _on_card_played(card_node: Control, tile_pos: Vector2i) -> void:
	if battle_active:
		return
	var data := card_node.data as CardData
	if data.card_type == CardData.CardType.WARRIOR:
		emit_signal("character_spawn_requested", data.character_data, tile_pos)
	elif data.card_type == CardData.CardType.PASSIVE:
		emit_signal("passive_played", data.passive_effect, 0.0)
	var remaining: int = get_child_count() - 1
	card_node.queue_free()
	if remaining <= 2 and not battle_active:
		battle_active = true
		emit_signal("fight_requested")
	else:
		await get_tree().process_frame
		deal_cards()
