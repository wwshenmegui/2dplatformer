extends Area2D

signal entered_deathzone(body)

func _ready() -> void:
	add_to_group("Deathzone")
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is CharacterBody2D:  # Assuming player is CharacterBody2D
		print("Body entered for deathzone")
		entered_deathzone.emit()
