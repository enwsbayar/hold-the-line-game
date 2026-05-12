extends Resource
class_name CardData

enum Rarity { BRONZE, SILVER, GOLD, EMERALD, DIAMOND }
enum CardType { WARRIOR, PASSIVE }
enum PassiveEffect {
	NONE,
	BOMB,             # tüm düşmanlara -10 hasar
	COIN,             # her player char %50 ile +%5 veya -%5 HP
	HEART,            # tüm player char +%2 HP
	NATURE_NECKLACE,  # tüm player char +%10 DEF
	SKULL,            # tüm player char +%10 ATK
	SWORD,            # tüm player char +1 ATK
	TIK,              # 2 ekstra kart çek
	X_MARK,           # rastgele 1 düşmanı öldür
}

@export var card_name: String = ""
@export var rarity: Rarity = Rarity.BRONZE
@export var card_type: CardType = CardType.WARRIOR
@export var character_data: CharacterData
@export var card_icon: Texture2D
@export var passive_effect: PassiveEffect = PassiveEffect.NONE
@export var description: String = ""
@export var weight: float = 100.0
