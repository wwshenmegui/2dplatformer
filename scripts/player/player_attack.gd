# scripts/player_attack.gd
extends Area2D

@export var damage = 1
@export var attack_duration = 0.3

# Swing arc, in degrees. The sword sweeps from start (up) to end (down).
@export var swing_start_angle = -60.0
@export var swing_end_angle = 60.0

var is_attacking = false

func _ready():
	# Turn off the collision shape initially
	$CollisionShape2D.disabled = true

	$AttackSprite.visible = false
	# Connect the body entered signal
	body_entered.connect(_on_body_entered)

func attack():
	if is_attacking:
		return

	is_attacking = true
	# Enable the collision shape for the duration of the attack
	$CollisionShape2D.disabled = false

	# Show the attack visual indicator (if any)
	$AttackSprite.visible = true

	# Mirror the swing direction when facing left so it still sweeps top-to-bottom.
	var facing = signf(scale.x)
	if facing == 0.0:
		facing = 1.0
	rotation = deg_to_rad(swing_start_angle) * facing

	# Swing the sword from up to down over the attack duration.
	var tween = create_tween()
	tween.tween_property(self, "rotation", deg_to_rad(swing_end_angle) * facing, attack_duration)
	await tween.finished
	end_attack()

func end_attack():
	is_attacking = false
	# Disable the collision shape
	$CollisionShape2D.disabled = true

	# Hide the attack visual indicator
	$AttackSprite.visible = false

	# Return the sword to its neutral resting angle.
	rotation = 0.0

func _on_body_entered(body):
	# Check if the body is an enemy
	if body.is_in_group("Enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
