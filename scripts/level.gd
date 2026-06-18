extends Node2D

@export var is_final_level = false
# Path to the next level scene; used when this is not the final level.
@export_file("*.tscn") var next_level_path: String = ""

@onready var respawn_point = $Respawn_Point
@onready var player = $Player
@onready var exit = $Exit
@onready var win_screen = $UILayer/WinScreen
@onready var lose_screen = $UILayer/LoseScreen
@onready var deathzone = $Deathzone
@onready var pause_menu = $UILayer/PauseMenu
@onready var backpack_ui = $UILayer/BackpackUI
@onready var boss_health_bar = $UILayer/BossHealthBar

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
		# A boss enemy clears the level when defeated and shows a health bar.
		if enemy.has_signal("boss_died"):
			enemy.boss_died.connect(_on_boss_died)
			boss_health_bar.setup("Dragon", enemy.max_health)
			enemy.health_changed.connect(_on_boss_health_changed)
		
	# Connect to deathzone signal
	deathzone.connect("entered_deathzone", _on_deathzone_body_entered)
		
	# Connect the exit signal
	exit.connect("exit_reached", _on_exit_reached)
	
	# Connect coin signals
	var coins = get_tree().get_nodes_in_group("Coins")
	for coin in coins:
		coin.connect("coin_collected", _on_coin_collected)
	
	# Connect collectible signals
	var collectibles = get_tree().get_nodes_in_group("Collectibles")
	for collectible in collectibles:
		collectible.connect("collected", _on_collectible_collected)

	# Connect weapon pickup signals
	var weapons = get_tree().get_nodes_in_group("Weapons")
	for weapon in weapons:
		weapon.connect("collected", _on_weapon_collected)

	# Connect armor pickup signals
	var armor_pickups = get_tree().get_nodes_in_group("ArmorPickups")
	for armor in armor_pickups:
		armor.connect("collected", _on_armor_collected)
	
	# Setup backpack UI - IMPORTANT: Set up inventory and player references
	backpack_ui.set_inventory(player.inventory)
	backpack_ui.set_player(player)
	
	# Hide pause menu and backpack UI at start
	pause_menu.visible = false
	backpack_ui.visible = false
	
func _unhandled_input(event):
	# ESC opens the pause menu during normal gameplay. When paused or when the
	# inventory is open, those UIs run with PROCESS_MODE_ALWAYS and handle ESC
	# themselves (consuming the event), while this node is frozen by the pause.
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func _on_exit_reached():
	if is_final_level:
		# Final level cleared — finish the game.
		win_screen.visible = true
		get_tree().paused = true
	elif next_level_path != "":
		# Carry the player's progress (HP, coins, inventory) into the next level.
		GameState.save_player(player)
		get_tree().change_scene_to_file(next_level_path)
		
func _on_player_died():
	lose_screen.visible = true
	get_tree().paused = true

func _on_boss_health_changed(current: int, max: int) -> void:
	boss_health_bar.update_health(current)

func _on_boss_died() -> void:
	# Defeating the boss wins the level.
	boss_health_bar.visible = false
	win_screen.visible = true
	get_tree().paused = true
	
func toggle_pause():
	# Don't pause if inventory is open
	if backpack_ui.visible:
		return
		
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

# handle collectible collection
func _on_collectible_collected(item_id):
	player.collect_item(item_id)

# handle weapon pickup
func _on_weapon_collected(weapon_id, props):
	player.collect_weapon(weapon_id, props)

# handle armor pickup
func _on_armor_collected(armor_id, props):
	player.collect_armor(armor_id, props)
	
# Handle coin collection
func _on_coin_collected(value):
	player.collect_coins(value)
