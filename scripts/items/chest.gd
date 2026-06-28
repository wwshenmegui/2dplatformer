extends Area2D
class_name Chest

# Emitted when the player opens the chest, reporting the coins inside.
signal chest_opened(coin_reward: int)

# Number of coins granted when the chest is opened.
@export var coin_reward: int = 5

# Sprite frames: 0 = closed, 1 = open (vertical 2-frame sheet).
const FRAME_CLOSED: int = 0
const FRAME_OPEN: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_label: Label = $InteractLabel

var is_open: bool = false
var player_in_range: bool = false

func _ready() -> void:
	add_to_group("Chests")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	sprite.frame = FRAME_CLOSED
	interact_label.visible = false

func _process(_delta: float) -> void:
	if player_in_range and not is_open and Input.is_action_just_pressed("interact"):
		open()

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_open:
		player_in_range = true
		interact_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		interact_label.visible = false

func open() -> void:
	is_open = true
	player_in_range = false
	sprite.frame = FRAME_OPEN
	interact_label.visible = false

	chest_opened.emit(coin_reward)

# Restore the opened appearance without granting a reward. Used when re-entering
# a level where this chest was already opened.
func set_opened() -> void:
	is_open = true
	player_in_range = false
	sprite.frame = FRAME_OPEN
	interact_label.visible = false
