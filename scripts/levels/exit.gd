extends Area2D

# Emitted when the player reaches this exit, carrying the scene to travel to.
signal exit_reached(target_level_path: String)

# Scene this exit zone leads to. Assign per-instance in the editor so one level
# can have several exits (e.g. a left zone returning to the previous level and a
# right zone advancing to the next). Leave empty on a final-level exit to let the
# level fall back to its next_level_path / win condition.
@export_file("*.tscn") var target_level_path: String = ""

# When a player is spawned directly on this exit (arriving from the level it
# leads to), the exit is disarmed so it doesn't immediately send them back. It
# re-arms once the player walks out of the zone.
var armed := true

func _ready():
	# Add this node to the "Exit" group so the level can wire up every exit.
	add_to_group("Exit")

	# Connect the body signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if armed and body is CharacterBody2D:  # Assuming player is CharacterBody2D
		emit_signal("exit_reached", target_level_path)

func _on_body_exited(body):
	# Re-arm once the player leaves, so re-entering this exit works normally.
	if body is CharacterBody2D:
		armed = true

# Suppress this exit until the player walks out of it. Used when the level
# spawns the player here on arrival from the destination level.
func disarm() -> void:
	armed = false
