extends Resource
class_name CharacterData

enum Rarity { BRONZE, SILVER, GOLD, EMERALD, DIAMOND }

@export var id: int = 0
@export var texture: Texture2D
@export var has_attack_anim: bool = true
@export var max_hp: int = 100
@export var atk: int = 10
@export var def: int = 2
@export var spd: float = 1.0
@export var move_speed: float = 30.0
@export var rarity: Rarity = Rarity.BRONZE
