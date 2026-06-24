extends Area2D

class_name ThrownBomb

# A bomb thrown by the player. It arcs under gravity, damages the first enemy it
# hits, then bursts (despawns) on contact with an enemy or terrain, or after its
# lifetime expires. The element drives its colour.
@export var element: Element.Type = Element.Type.FIRE
@export var damage: int = 2
@export var fall_gravity: float = 1200.0
@export var lifetime: float = 4.0

# Travel velocity. Set by the thrower (see Player.throw_bomb) before the bomb is
# added to the scene tree.
var velocity: Vector2 = Vector2.ZERO
var _spent: bool = false

func _ready() -> void:
	var square = get_node_or_null("Square")
	if square:
		square.color = Element.get_color(element)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	velocity.y += fall_gravity * delta
	global_position += velocity * delta
	rotation += delta * 6.0  # tumble as it flies

func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	_spent = true
	# Damage an enemy on a direct hit, carrying this bomb's element so enemies
	# with an affinity (e.g. the Dragon) can resist or take extra. The bomb
	# bursts on any contact.
	if body.is_in_group("Enemies") and body.has_method("take_damage"):
		body.take_damage(damage, element)
	queue_free()
