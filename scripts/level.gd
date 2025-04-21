extends Node2D

@export var is_final_level = false

@onready var respawn_point = $Respawn_Point
@onready var player = $Player
@onready var exit = $Exit
@onready var win_screen = $UILayer/WinScreen
@onready var lose_screen = $UILayer/LoseScreen
@onready var deathzone = $Deathzone
@onready var pause_menu = $UILayer/PauseMenu

var is_paused = false

func _ready():
	get_tree().paused = false
	# Find all enemies in the scene
	var enemies = get_tree().get_nodes_in_group("Enemies")
	
	# Connect to player's signal
	player.connect("player_died", _on_player_died)
	
	# Connect to each enemy's signal
	for enemy in enemies:
		enemy.connect("damage_player", _on_enemy_damage_player)
		
	# Connect to deathzone signal
	deathzone.connect("entered_deathzone", _on_deathzone_body_entered)
		
	# Connect the exit signal
	# You need to get a reference to your exit node
	# Assuming the exit is named "Exit" in your scene:
	exit.connect("exit_reached", _on_exit_reached)
	
	# Hide pause menu at start
	pause_menu.visible = false
	
func _process(delta):
	# Check for pause input
	if Input.is_action_just_pressed("ui_cancel"):  # ESC key
		toggle_pause()

func _on_exit_reached():
	if is_final_level:
		win_screen.visible = true
		get_tree().paused = true
		
func _on_player_died():
	lose_screen.visible = true
	get_tree().paused = true
	
func toggle_pause():
	is_paused = !is_paused
	
	if is_paused:
		# Pause the game
		get_tree().paused = true
		pause_menu.visible = true
	else:
		# Unpause the game
		get_tree().paused = false
		pause_menu.visible = false
	

func _on_deathzone_body_entered() -> void:
	reset_player()
	
func _on_enemy_damage_player() -> void:
	# TODO repel player in the future
	pass
	
func reset_player():
	if not player.is_dead:	
		player.velocity = Vector2.ZERO
		player.global_position = $Respawn_Point.global_position
