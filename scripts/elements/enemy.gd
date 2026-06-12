extends CharacterBody2D

signal damage_player(body)
signal enemy_died

@export var speed = 100
var direction = -1
var gravity = 30
var is_on_edge = false

@export var max_health = 3
@export var damage = 1

# Reaction to being hit by the player's weapon.
@export var repel_strength = 650.0   # base push speed when a weapon repels
@export var effect_duration = 0.4    # how long a slow/repel lasts
# Temporary speed multiplier from a positive-slowdown weapon (1.0 = normal).
var slow_factor = 1.0
# When repelled, the enemy is launched and ignores patrol until the timer ends.
var is_repelled = false
var effect_timer = 0.0

var current_health = max_health
var is_dead = false

@onready var edge_check = $EdgeCheck
@onready var enemy_body = $Area2D
@onready var sprite = $Sprite2D

func _ready() -> void:
	# Set up initial state
	add_to_group("Enemies")
	current_health = max_health
	
	# Check for collisions with the player
	enemy_body.connect("body_entered", _on_area_2d_body_entered)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity

	# Tick down any temporary slow/repel effect from a weapon hit.
	if effect_timer > 0.0:
		effect_timer -= delta
		if effect_timer <= 0.0:
			slow_factor = 1.0
			is_repelled = false

	# While repelled, keep the launched velocity and skip normal patrol.
	if is_repelled:
		move_and_slide()
		return

	# Handle horizontal movement (slowed while a weapon's slow effect is active)
	velocity.x = direction * speed * slow_factor

	# Move the enemy
	move_and_slide()

	# Check if we need to change direction
	check_direction()

# Called by the player's attack. A positive amount slows the enemy; a negative
# amount repels it away from the attack's origin (a knockback).
func apply_attack_slowdown(amount: float, source_position: Vector2) -> void:
	if is_dead:
		return

	effect_timer = effect_duration

	if amount >= 0.0:
		# Temporarily reduce movement speed.
		slow_factor = clampf(1.0 - amount, 0.0, 1.0)
		is_repelled = false
	else:
		# Launch the enemy away from the player.
		var away = signf(global_position.x - source_position.x)
		if away == 0.0:
			away = 1.0
		velocity.x = away * repel_strength * abs(amount)
		velocity.y = -250.0
		is_repelled = true
		# Face the direction it's being pushed.
		direction = int(away)

func check_direction():
	# Check if we hit a wall
	if is_on_wall():
		direction *= -1  # Reverse direction
		# Move a bit in the new direction to prevent getting stuck
		position.x += direction * 5
		
	# Check if we're at an edge using the edge_check raycast
	if edge_check.is_colliding() == false and is_on_floor():
		direction *= -1  # Reverse direction
		# Move a bit in the new direction to prevent getting stuck
		position.x += direction * 5
		
	# Update sprite direction
	if direction < 0:
		# Facing left
		$Sprite2D.flip_h = true
	else:
		# Facing right
		$Sprite2D.flip_h = false


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("take_damage") and not body.is_invincible:
		body.take_damage(damage, global_position)
		damage_player.emit()
		
func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
		
	current_health -= amount
	
	# Flash the enemy or play damage effect
	modulate = Color(1, 0.5, 0.5)  # Red tint
	await get_tree().create_timer(0.2).timeout
	modulate = Color(1, 1, 1)  # Reset tint
	
	if current_health <= 0:
		die()

func die() -> void:
	is_dead = true
	# Disable collision
	$CollisionShape2D.disabled = true
	$Area2D/CollisionShape2D.disabled = true
	
	# Play death animation or effect
	speed = 0
	sprite.modulate.a = 0.7  # Make semi-transparent
	
	# Optional: play death animation if available
	# $AnimationPlayer.play("die")
	
	# Notify that this enemy died
	enemy_died.emit()
	
	# Remove after a delay
	await get_tree().create_timer(1.0).timeout
	queue_free()
