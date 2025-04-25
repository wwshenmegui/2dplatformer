extends Area2D

signal entered_deathzone(body)

@export var damage = 1

func _ready() -> void:
	add_to_group("Deathzone")
	
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body):
	if body is CharacterBody2D:  # Assuming player is CharacterBody2D
		print("Body entered deathzone")
		if body.has_method("take_damage"):
			body.take_damage(damage)
		entered_deathzone.emit()
