extends Area2D

# Emitted when the player reaches this exit, carrying the scene to travel to.
signal exit_reached(target_level_path: String)

# Scene this exit zone leads to. Assign per-instance in the editor so one level
# can have several exits (e.g. a left zone returning to the previous level and a
# right zone advancing to the next). Leave empty on a final-level exit to let the
# level fall back to its next_level_path / win condition.
@export_file("*.tscn") var target_level_path: String = ""

func _ready():
	# Add this node to the "Exit" group so the level can wire up every exit.
	add_to_group("Exit")

	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is CharacterBody2D:  # Assuming player is CharacterBody2D
		emit_signal("exit_reached", target_level_path)
