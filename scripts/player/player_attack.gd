# scripts/player_attack.gd
extends Area2D

@export var damage = 1
@export var attack_duration = 0.3

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
	
	# Create a timer to automatically end the attack
	await get_tree().create_timer(attack_duration).timeout
	end_attack()

func end_attack():
	is_attacking = false
	# Disable the collision shape
	$CollisionShape2D.disabled = true
	
	# Hide the attack visual indicator
	$AttackSprite.visible = false

func _on_body_entered(body):
	# Check if the body is an enemy
	if body.is_in_group("Enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
