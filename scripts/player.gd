extends CharacterBody2D

class_name Player

@export var speed = 300
@export var gravity = 30
@export var jumpforce = 600

var active = true

@onready var animated_sprite = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("Player")

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
	
	
