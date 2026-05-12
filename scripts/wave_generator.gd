extends Node
class_name WaveGenerator

# Tüm düşman CharacterData'ları buraya yükle
var enemy_pool: Array[CharacterData] = []
var enemy_bonuses := {"hp": 1.0, "atk": 1.0, "def": 1.0, "spd": 1.0}

func _init() -> void:
	_load_enemy_pool()

func _load_enemy_pool() -> void:
	for i in range(1, 99):
		var p := "res://assets/enemy_data/char_%d_data.tres" % i
		if ResourceLoader.exists(p):
			var res := load(p) as CharacterData
			if res != null:
				enemy_pool.append(res)
		else:
			break

const RARITY_WEIGHTS = {
	CharacterData.Rarity.BRONZE:  100.0,
	CharacterData.Rarity.SILVER:   60.0,
	CharacterData.Rarity.GOLD:     40.0,
	CharacterData.Rarity.EMERALD:  25.0,
	CharacterData.Rarity.DIAMOND:  15.0,
}

func generate(wave_number: int) -> WaveData:
	var wave := WaveData.new()
	wave.wave_number = wave_number
	wave.spawn_interval = max(0.4, 1.5 - wave_number * 0.05)
	var count: int = wave_number + 1
	for i in count:
		var base: CharacterData = _pick_enemy()
		var scaled: CharacterData = _scale_enemy(base, wave_number)
		if scaled != null:
			wave.enemies.append(scaled)
	return wave

func _pick_enemy() -> CharacterData:
	if enemy_pool.is_empty():
		return null
	var total: float = 0.0
	for e in enemy_pool:
		total += RARITY_WEIGHTS.get(e.rarity, 100.0)
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for e in enemy_pool:
		cumulative += RARITY_WEIGHTS.get(e.rarity, 100.0)
		if roll <= cumulative:
			return e
	return enemy_pool[-1]

func _scale_enemy(base: CharacterData, wave: int) -> CharacterData:
	if base == null:
		return null
	var scaled := CharacterData.new()
	scaled.texture = base.texture
	scaled.has_attack_anim = base.has_attack_anim
	var mult: float = 1.0 + wave * 0.1
	scaled.max_hp  = int(base.max_hp  * mult * enemy_bonuses["hp"])
	scaled.atk     = int(base.atk     * mult * enemy_bonuses["atk"])
	scaled.def     = int(base.def     * mult * enemy_bonuses["def"])
	scaled.spd     = base.spd * enemy_bonuses["spd"]
	scaled.move_speed = base.move_speed
	return scaled
