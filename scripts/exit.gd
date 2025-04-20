extends Area2D

signal exit_reached

func _ready():
	# Add this node to the "Exit" group
	add_to_group("Exit")
	
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is CharacterBody2D:  # Assuming player is CharacterBody2D
		print("Player reached exit!")
		emit_signal("exit_reached")
		# The World scene will handle showing the label
