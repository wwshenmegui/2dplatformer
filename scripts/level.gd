extends Node2D

@export var is_final_level = false

@onready var respawn_point = $Respawn_Point
@onready var player = $Player
@onready var exit = $Exit
@onready var win_screen = $UILayer/WinScene
@onready var deathzone = $Deathzone

func _ready():
	# Find all enemies in the scene
	var enemies = get_tree().get_nodes_in_group("Enemies")
	
	# Connect to each enemy's signal
	for enemy in enemies:
		enemy.connect("kill_player", _on_enemy_kill_player)
		
	# Connect to deathzone signal
	deathzone.connect("entered_deathzone", _on_deathzone_body_entered)
		
	# Connect the exit signal
	# You need to get a reference to your exit node
	# Assuming the exit is named "Exit" in your scene:
	exit.connect("exit_reached", _on_exit_reached)

func _on_exit_reached():
	if is_final_level:
		player.active = false
		win_screen.visible = true
		

func _on_deathzone_body_entered() -> void:
	reset_player()
	
func _on_enemy_kill_player() -> void:
	reset_player()
	
func reset_player():
	player.velocity = Vector2.ZERO
	player.global_position = $Respawn_Point.global_position
