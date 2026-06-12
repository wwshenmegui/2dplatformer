extends Area2D

class_name Sword

# Emitted when the player picks this weapon up. Carries the weapon id and a
# property dictionary so the inventory can store and later equip it.
signal collected(weapon_id: String, props: Dictionary)

@export var weapon_id: String = "straight_sword"
@export var weapon_name: String = "Straight Sword"
@export var description: String = "A balanced blade."
@export var weapon_texture: Texture2D

# Combat stats applied to the player while this weapon is equipped.
@export var attack_speed: float = 1.0
@export var damage: int = 1
# Visual length of the swing sprite relative to the giant sword (1.0 = full).
@export var attack_scale: float = 1.0
# Movement slowdown applied while swinging. Positive slows the player and any
# enemy that is hit; negative instead repels enemies away from the player.
@export var slowdown: float = 0.0

var player_in_range: bool = false
var interact_label: Label

func _ready() -> void:
	add_to_group("Weapons")

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

# Bundle this weapon's data into a dictionary for the inventory.
func get_properties() -> Dictionary:
	return {
		"name": weapon_name,
		"description": description,
		"attack_speed": attack_speed,
		"damage": damage,
		"attack_scale": attack_scale,
		"slowdown": slowdown,
		"icon_texture": weapon_texture,
	}

func collect() -> void:
	collected.emit(weapon_id, get_properties())

	interact_label.visible = false
	player_in_range = false

	# Visual feedback, then remove the pickup from the world.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)
