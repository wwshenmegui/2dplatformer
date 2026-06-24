extends Area2D

class_name Collectible

signal collected(item_id)

@export var item_id: String = "health_potion"
@export var item_name: String = "Health Potion"
@export var item_texture: Texture2D

var player_in_range: bool = false
var interact_label: Label

func _ready():
	add_to_group("Collectibles")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create interaction label
	interact_label = Label.new()
	interact_label.text = "Press E to collect"
	interact_label.visible = false
	interact_label.position = Vector2(-50, -50)  # Position above the item
	
	# Set up label appearance
	interact_label.add_theme_color_override("font_color", Color(1, 1, 1))
	interact_label.add_theme_font_size_override("font_size", 12)
	
	add_child(interact_label)

func _process(delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		collect_item()

func _on_body_entered(body):
	if body is Player:
		player_in_range = true
		interact_label.visible = true

func _on_body_exited(body):
	if body is Player:
		player_in_range = false
		interact_label.visible = false

func collect_item():
	# Emit signal with the item ID
	collected.emit(item_id)
	
	# Hide interaction label and disable interaction
	interact_label.visible = false
	player_in_range = false
	
	# Visual feedback (optional)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)
