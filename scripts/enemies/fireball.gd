extends Area2D

## Projectile spat out by the Dragon's ranged fire attack. It flies in a fixed
## direction, damages the player on contact, and despawns on any solid hit or
## after its lifetime runs out.

@export var speed: float = 420.0
@export var damage: int = 1
@export var lifetime: float = 3.0

# Travel direction, set by whoever spawns the fireball (see Dragon.breathe_fire).
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Point the visual along the travel direction and despawn after lifetime.
	rotation = direction.angle()
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Damage the player on a direct hit; either way the fireball fizzles out on
	# any contact (player or terrain).
	if body.is_in_group("Player") and body.has_method("take_damage") and not body.is_invincible:
		body.take_damage(damage, global_position)
	queue_free()
