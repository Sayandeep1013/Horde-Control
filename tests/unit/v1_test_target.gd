extends Node2D
## Stand-in for the player or the Tower in v1.0 enemy tests: a Node2D with a
## real Hurtbox (so EnemyBlast's hit path is the production one) that logs every
## amount it receives.

@export var faction: Hurtbox.Faction = Hurtbox.Faction.PLAYER
var hurtbox: Hurtbox = null
var damage_log: Array[float] = []


func _ready() -> void:
	hurtbox = Hurtbox.new()
	hurtbox.faction = faction
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	hurtbox.add_child(shape)
	add_child(hurtbox)
	hurtbox.damage_received.connect(func(amount: float, _source: Variant, _hitbox: Node) -> void: damage_log.append(amount))


func total_damage() -> float:
	var t: float = 0.0
	for d in damage_log:
		t += d
	return t
