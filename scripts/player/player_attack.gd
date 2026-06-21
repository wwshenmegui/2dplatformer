# scripts/player_attack.gd
extends Area2D

@export var damage = 1
@export var attack_duration = 0.3

var is_attacking = false

# Movement slowdown of the equipped weapon, forwarded to enemies that are hit.
var slowdown: float = 0.0

func _ready():
	# Turn off the collision shape initially
	$CollisionShape2D.disabled = true
	# Connect the body entered signal
	body_entered.connect(_on_body_entered)

# Configure the swing for the equipped weapon. The swing visual now comes from
# the player's own attack animation, so only the movement slowdown is stored
# here (texture/scale arguments are kept for signature compatibility).
func set_weapon(_texture: Texture2D, _scale_factor: float, slowdown_value: float) -> void:
	slowdown = slowdown_value

func attack():
	if is_attacking:
		return

	is_attacking = true
	# Enable the collision shape for the duration of the attack
	$CollisionShape2D.disabled = false

	await get_tree().create_timer(attack_duration).timeout
	end_attack()

func end_attack():
	is_attacking = false
	# Disable the collision shape
	$CollisionShape2D.disabled = true

func _on_body_entered(body):
	# Check if the body is an enemy
	if body.is_in_group("Enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		# Slow (or, when negative, repel) the enemy with the weapon's slowdown.
		if body.has_method("apply_attack_slowdown"):
			body.apply_attack_slowdown(slowdown, global_position)
