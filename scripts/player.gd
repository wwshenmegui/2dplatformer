extends CharacterBody2D

class_name Player

signal player_died

@export var speed = 300
@export var gravity = 30
@export var jumpforce = 600

@export var max_hp = 1
var current_hp = max_hp
var is_dead = false

# whether player can move
var active = true

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
	
	if active == true:
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y -= jumpforce
		
		var horizontal_direction = Input.get_axis("move_left", "move_right")
		
		velocity.x = speed * horizontal_direction
		move_and_slide()
	
		update_animation(horizontal_direction)
	
func update_animation(direction):
	if direction != 0:
		animated_sprite.flip_h = (direction == -1)
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
			
func update_hp_display():
	# Signal to update the HUD
	var hud = get_node("/root/Level/UILayer/HpHud")
	if hud:
		hud.update_health(current_hp)

	
func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
		
	current_hp -= amount
	update_hp_display()
	
	if current_hp <= 0:
		die()
	
func heal(amount: int = 1) -> void:
	current_hp = min(current_hp + amount, max_hp)
	update_hp_display()

func die() -> void:
	is_dead = true
	# You might want to play death animation here
	# Disable player controls
	set_physics_process(false)
	# Notify level about player death
	player_died.emit()
	
	
