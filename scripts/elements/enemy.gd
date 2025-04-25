extends CharacterBody2D

signal damage_player(body)
signal enemy_died

var speed = 100
var direction = -1
var gravity = 30
var is_on_edge = false

@export var max_health = 3
@export var damage = 1

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
	# Handle horizontal movement
	velocity.x = direction * speed
	
	# Move the enemy
	move_and_slide()
	
	# Check if we need to change direction
	check_direction()

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
