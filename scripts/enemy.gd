extends CharacterBody2D

signal damage_player(body)

var speed = 100
var direction = -1
var gravity = 30
var is_on_edge = false

@export var damage = 1

@onready var edge_check = $EdgeCheck
@onready var enemy_body = $Area2D

func _ready() -> void:
	# Set up initial state
	add_to_group("Enemies")
	
	# Check for collisions with the player
	enemy_body.connect("body_entered", _on_area_2d_body_entered)

func _physics_process(delta: float) -> void:
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
