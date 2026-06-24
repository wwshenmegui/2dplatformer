extends Area2D

class_name Armor

# Emitted when the player picks this armor up. Carries the armor id and a
# property dictionary so the inventory can store and later equip it.
signal collected(armor_id: String, props: Dictionary)

@export var armor_id: String = "head_armor"
@export var armor_name: String = "Iron Helm"
@export var description: String = "Protects the head."
@export var armor_texture: Texture2D
# Body slot this piece occupies: "head", "chest", "hand", or "foot".
@export var slot: String = "head"
# Damage mitigation granted while this piece is equipped.
@export var armor_value: int = 1

var player_in_range: bool = false
var interact_label: Label

func _ready() -> void:
	add_to_group("ArmorPickups")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create interaction label
	interact_label = Label.new()
	interact_label.text = "Press E to pick up"
	interact_label.visible = false
	interact_label.position = Vector2(-50, -50)
	interact_label.add_theme_color_override("font_color", Color(1, 1, 1))
	interact_label.add_theme_font_size_override("font_size", 12)
	add_child(interact_label)

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		collect()

func _on_body_entered(body: Node) -> void:
	if body is Player:
		player_in_range = true
		interact_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body is Player:
		player_in_range = false
		interact_label.visible = false

# Bundle this armor's data into a dictionary for the inventory.
func get_properties() -> Dictionary:
	return {
		"name": armor_name,
		"description": description,
		"slot": slot,
		"armor_value": armor_value,
		"icon_texture": armor_texture,
	}

func collect() -> void:
	collected.emit(armor_id, get_properties())

	interact_label.visible = false
	player_in_range = false

	# Visual feedback, then remove the pickup from the world.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)
