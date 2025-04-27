extends Area2D

signal coin_collected(value)

@export var coin_value: int = 1

func _ready():
	# Add this node to the "Coins" group
	add_to_group("Coins")
	
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is Player:
		# Auto-collect the coin
		collect_coin(body)

func collect_coin(player):
	# Play collection animation/sound
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)
	
	# Emit signal with coin value
	coin_collected.emit(coin_value)
