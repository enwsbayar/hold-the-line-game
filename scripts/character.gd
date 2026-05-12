extends Node2D

signal died(character)

@export var max_hp: int = 100
@export var atk: int = 10
@export var def: int = 2
@export var spd: float = 1.5
@export var has_attack_anim: bool = true

var hp: int
var tile_pos: Vector2i
var spawn_tile: Vector2i
var is_player_side: bool = true
var is_dead: bool = false
var frozen: bool = false
var source_path: String = ""

var _target: Node2D = null
var _move_timer: float = 0.0
var _attack_timer: float = 0.0
var _tilemap: TileMapLayer = null
var _is_attacking: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _hp_bar_bg: ColorRect
var _hp_bar_fill: ColorRect
const BAR_WIDTH := 16
const BAR_HEIGHT := 2
const BAR_OFFSET_Y := -12

func _ready() -> void:
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_bar_bg.position = Vector2(-BAR_WIDTH / 2.0, BAR_OFFSET_Y)
	_hp_bar_bg.color = Color(0.2, 0.2, 0.2)
	add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_bar_fill.position = Vector2(-BAR_WIDTH / 2.0, BAR_OFFSET_Y)
	_hp_bar_fill.color = Color(0.1, 0.9, 0.1)
	add_child(_hp_bar_fill)

func _update_hp_bar() -> void:
	if _hp_bar_fill == null:
		return
	var pct: float = float(hp) / float(max_hp)
	_hp_bar_fill.size.x = BAR_WIDTH * pct
	if pct > 0.5:
		_hp_bar_fill.color = Color(0.1, 0.9, 0.1)
	elif pct > 0.25:
		_hp_bar_fill.color = Color(0.9, 0.7, 0.1)
	else:
		_hp_bar_fill.color = Color(0.9, 0.1, 0.1)

func setup(pos: Vector2i, player_side: bool, tilemap: TileMapLayer, texture: Texture2D) -> void:
	hp = max_hp
	tile_pos = pos
	spawn_tile = pos
	is_player_side = player_side
	_tilemap = tilemap
	position = _tilemap.map_to_local(tile_pos)
	anim.sprite_frames = _build_frames(texture)
	anim.flip_h = not player_side
	anim.play("walk")

func _build_frames(texture: Texture2D) -> SpriteFrames:
	if texture == null:
		push_error("Character: texture null! CharacterData'da texture atanmamış.")
		return SpriteFrames.new()
	var total_frames: int = 12 if has_attack_anim else 8
	var fw: int = texture.get_width() / total_frames
	var fh: int = texture.get_height()
	var sf := SpriteFrames.new()

	if has_attack_anim:
		_add_anim(sf, "attack", texture, 0, 4, fw, fh)
		_add_anim(sf, "walk",   texture, 4, 4, fw, fh)
		_add_anim(sf, "death",  texture, 8, 4, fw, fh)
	else:
		_add_anim(sf, "walk",  texture, 0, 4, fw, fh)
		_add_anim(sf, "death", texture, 4, 4, fw, fh)

	sf.set_animation_speed("walk",  8.0)
	sf.set_animation_speed("death", 6.0)
	if has_attack_anim:
		sf.set_animation_speed("attack", 10.0)
		sf.set_animation_loop("attack", false)
	sf.set_animation_loop("death", false)
	return sf

func _add_anim(sf: SpriteFrames, anim_name: String, tex: Texture2D,
		start: int, count: int, fw: int, fh: int) -> void:
	sf.add_animation(anim_name)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2((start + i) * fw, 0, fw, fh)
		sf.add_frame(anim_name, atlas)

const ATTACK_RANGE := 20.0
const MOVE_SPEED := 30.0

func _process(delta: float) -> void:
	if is_dead or _tilemap == null or _is_attacking or frozen:
		return

	_attack_timer -= delta
	_target = _find_nearest_enemy()

	if _target == null or not is_instance_valid(_target):
		return

	var dist := position.distance_to(_target.position)

	if dist <= ATTACK_RANGE:
		if _attack_timer <= 0.0:
			_do_attack(_target)
			_attack_timer = 1.0 / spd
	else:
		var dir := (_target.position - position).normalized()
		position += dir * MOVE_SPEED * delta

func _find_nearest_enemy() -> Node2D:
	var group: String = "enemy_characters" if is_player_side else "player_characters"
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(e):
			continue
		var other := e as Node2D
		if other == null:
			continue
		var other_pos: Vector2i = other.get("tile_pos")
		var d: float = float(tile_pos.distance_squared_to(other_pos))
		if d < nearest_dist:
			nearest_dist = d
			nearest = other
	return nearest


func _do_attack(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	if has_attack_anim:
		_is_attacking = true
		anim.play("attack")
		await anim.animation_finished
		_is_attacking = false
		if not is_dead:
			anim.play("walk")
		if not is_instance_valid(target) or target.get("is_dead"):
			return
	var target_def: int = target.get("def")
	var damage: int = max(1, atk - target_def)
	target.call("take_damage", damage)

func reset_for_next_wave(tilemap: TileMapLayer, new_tile: Vector2i = spawn_tile) -> void:
	hp = max_hp
	_update_hp_bar()
	tile_pos = new_tile
	spawn_tile = new_tile
	_tilemap = tilemap
	position = _tilemap.map_to_local(tile_pos)
	frozen = true
	is_dead = false
	_is_attacking = false
	_target = null
	set_process(true)
	anim.play("walk")

func take_damage(amount: int) -> void:
	hp -= amount
	_update_hp_bar()
	_hit_flash()
	if hp <= 0 and not is_dead:
		_die()

func _hit_flash() -> void:
	var tween := create_tween()
	tween.tween_property(anim, "modulate", Color(1, 0.2, 0.2), 0.05)
	tween.tween_property(anim, "modulate", Color.WHITE, 0.1)

func _die() -> void:
	is_dead = true
	set_process(false)
	anim.play("death")
	await anim.animation_finished
	emit_signal("died", self)
	queue_free()
