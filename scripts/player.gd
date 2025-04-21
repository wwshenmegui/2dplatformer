extends CharacterBody2D

class_name Player

signal player_died

# movement variables
@export var speed = 300
@export var gravity = 30
@export var jumpforce = 600

@export var max_hp = 3
var current_hp = max_hp
var is_dead = false

# invincibility properties
var is_invincible = false
var invincibility_duration = 1.5  # Duration in seconds
var invincibility_timer = 0.0
var flash_timer = 0.0

# Knockback variables
var knockback_force = Vector2(300, -200)  # Horizontal and vertical force
var is_being_knocked_back = false
var knockback_direction = Vector2.ZERO

@onready var animated_sprite = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("Player")
	
	# Your existing code...
	current_hp = max_hp
	# Notify the HUD to update
	update_hp_display()


func _physics_process(delta: float) -> void:
	# Add the gravity
	if not is_on_floor():
		velocity.y += gravity
		if velocity.y > 500:
			velocity.y = 500
	
	var horizontal_direction = 0
	if not is_being_knocked_back:
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y -= jumpforce
		
		horizontal_direction = Input.get_axis("move_left", "move_right")
		
		velocity.x = speed * horizontal_direction
		
	move_and_slide()

	update_animation(horizontal_direction)
		
	# Check if knockback should end
	if is_being_knocked_back and is_on_floor() and velocity.y >= 0:
		is_being_knocked_back = false
	
func update_animation(direction):
	if direction != 0:
		animated_sprite.flip_h = (direction == -1)
	if is_on_floor():
		if not is_invincible:
			if direction == 0:
				animated_sprite.play("idle")
			else:
				animated_sprite.play("run")
		else:
			# play invincible animation
			animated_sprite.play("take_damage")
			
func update_hp_display():
	# Signal to update the HUD
	var hud = get_node("/root/Level/UILayer/HpHud")
	if hud:
		hud.update_health(current_hp)

	
func take_damage(amount: int = 1, knockback_source_position = null) -> void:
	if is_dead:
		return
		
	current_hp -= amount
	update_hp_display()
	
	# Apply knockback if a source position is provided
	if knockback_source_position != null:
		apply_knockback(knockback_source_position)
	
	if current_hp <= 0:
		die()
	else:
		start_invincibility()
		
func apply_knockback(source_position):
	# Calculate direction away from the source (only for horizontal direction)
	var dir_to_player = global_position - source_position
	knockback_direction.x = 1 if dir_to_player.x > 0 else -1
	
	# Apply the knockback as an impulse
	velocity.x = knockback_direction.x * knockback_force.x
	velocity.y = knockback_force.y  # Always jump up a bit
	
	is_being_knocked_back = true
		
func start_invincibility():
	is_invincible = true
	invincibility_timer = invincibility_duration
	await get_tree().create_timer(invincibility_timer).timeout
	end_invincibility()
	
func end_invincibility():
	is_invincible = false
	
func heal(amount: int = 1) -> void:
	current_hp = min(current_hp + amount, max_hp)
	update_hp_display()

func die() -> void:
	is_dead = true
	# You might want to play death animation here
	# Disable player controls
	set_physics_process(false)
	animated_sprite.play("die")
	await get_tree().create_timer(1.0).timeout
	# Notify level about player death
	player_died.emit()
	
	
