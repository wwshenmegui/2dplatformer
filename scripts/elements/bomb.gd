extends Area2D

class_name Bomb

# An elemental bomb pickup. Bombs are *ranged weapons*: once picked up they live
# in the inventory's weapon section, can be equipped, and are thrown as
# projectiles (see thrown_bomb.tscn). The element drives the bomb's id, display
# name, colour, and the projectile it throws.
#
# Pickup mirrors the melee weapon pickup flow (see Sword): it joins the "Weapons"
# group and emits collected(weapon_id, props), which the level routes into
# player.collect_weapon.
signal collected(weapon_id: String, props: Dictionary)

const THROWN_BOMB = preload("res://scenes/elements/thrown_bomb.tscn")

@export var element: Element.Type = Element.Type.FIRE
# Damage dealt to an enemy the thrown bomb hits.
@export var damage: int = 2

var player_in_range: bool = false
var interact_label: Label

func _ready() -> void:
	add_to_group("Weapons")

	# Colour the square pickup with the element's colour.
	var square = get_node_or_null("Square")
	if square:
		square.color = Element.get_color(element)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

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

# Inventory id for this bomb, e.g. "fire_bomb".
func get_weapon_id() -> String:
	return Element.get_key(element) + "_bomb"

# Bundle this bomb's data for the inventory's weapon section. "type": "ranged"
# marks it as a throwable; "count" is the ammo a single pickup grants.
func get_properties() -> Dictionary:
	var element_name := Element.get_display_name(element)
	return {
		"name": element_name + " Bomb",
		"description": "Throwable %s bomb. Equip and press J to throw." % element_name,
		"type": "ranged",
		"element": element,
		"damage": damage,
		"count": 1,
		"throw_scene": THROWN_BOMB,
		"icon_texture": Element.make_square_texture(Element.get_color(element)),
	}

func collect() -> void:
	collected.emit(get_weapon_id(), get_properties())

	interact_label.visible = false
	player_in_range = false

	# Visual feedback, then remove the pickup from the world.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)
