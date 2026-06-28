extends Node2D

@export var is_final_level = false
# Path to the next level scene; used when this is not the final level.
@export_file("*.tscn") var next_level_path: String = ""

@onready var respawn_point = $Respawn_Point
@onready var player = $Player
@onready var win_screen = $UILayer/WinScreen
@onready var lose_screen = $UILayer/LoseScreen
@onready var deathzone = $Deathzone
@onready var pause_menu = $UILayer/PauseMenu
@onready var backpack_ui = $UILayer/BackpackUI
@onready var boss_health_bar = $UILayer/BossHealthBar

var is_paused = false

# Identifies this level for per-level world state stored in GameState. Uses the
# scene path so it is independent of the root node's name.
var _level_id: String

func _ready():
	get_tree().paused = false
	_level_id = scene_file_path
	# Find all enemies in the scene
	var enemies = get_tree().get_nodes_in_group("Enemies")

	# Connect to player's signal
	player.connect("player_died", _on_player_died)

	# Clamp the player camera to the level bounds so it never reveals the
	# grey out-of-bounds area beyond the tilemap.
	_setup_camera_limits()
	
	# Connect to each enemy's signal
	for enemy in enemies:
		enemy.connect("damage_player", _on_enemy_damage_player)
		# Record this enemy's defeat so it stays gone when re-entering the level.
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_enemy_died.bind(enemy))
		# A boss enemy clears the level when defeated and shows a health bar.
		if enemy.has_signal("boss_died"):
			enemy.boss_died.connect(_on_boss_died)
			boss_health_bar.setup("Dragon", enemy.max_health)
			enemy.health_changed.connect(_on_boss_health_changed)
		
	# Connect to deathzone signal
	deathzone.connect("entered_deathzone", _on_deathzone_body_entered)
		
	# Connect every exit zone. Each exit carries its own destination scene, so a
	# level can have multiple (e.g. a left zone back and a right zone forward).
	for exit in get_tree().get_nodes_in_group("Exit"):
		exit.connect("exit_reached", _on_exit_reached)
	
	# Connect coin signals
	var coins = get_tree().get_nodes_in_group("Coins")
	for coin in coins:
		coin.coin_collected.connect(_on_coin_collected.bind(coin))

	# Connect collectible signals
	var collectibles = get_tree().get_nodes_in_group("Collectibles")
	for collectible in collectibles:
		collectible.collected.connect(_on_collectible_collected.bind(collectible))

	# Connect chest signals
	var chests = get_tree().get_nodes_in_group("Chests")
	for chest in chests:
		chest.chest_opened.connect(_on_chest_opened.bind(chest))

	# Connect weapon pickup signals
	var weapons = get_tree().get_nodes_in_group("Weapons")
	for weapon in weapons:
		weapon.collected.connect(_on_weapon_collected.bind(weapon))

	# Connect armor pickup signals
	var armor_pickups = get_tree().get_nodes_in_group("ArmorPickups")
	for armor in armor_pickups:
		armor.collected.connect(_on_armor_collected.bind(armor))

	# Setup backpack UI - IMPORTANT: Set up inventory and player references
	backpack_ui.set_inventory(player.inventory)
	backpack_ui.set_player(player)

	# Hide pause menu and backpack UI at start
	pause_menu.visible = false
	backpack_ui.visible = false

	# Reapply any world state from a previous visit (opened chests, defeated
	# enemies, collected pickups), then place the player at the correct entrance.
	_apply_level_state()
	_position_player_at_entry()
	
# Derive the player camera's limits from the level's TileMapLayer extents so the
# view stays inside the playable area regardless of each level's size.
func _setup_camera_limits():
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera == null:
		return

	# Union the world-space bounds of every TileMapLayer child so levels built
	# from multiple layers (terrain/water/overhang) are fully covered.
	var bounds := Rect2()
	var has_bounds := false
	for child in get_children():
		if not (child is TileMapLayer) or child.tile_set == null:
			continue
		var used: Rect2i = child.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var tile_size: Vector2i = child.tile_set.tile_size
		var rect := Rect2(
			child.global_position + Vector2(used.position * tile_size),
			Vector2(used.size * tile_size))
		bounds = rect if not has_bounds else bounds.merge(rect)
		has_bounds = true

	if not has_bounds:
		return

	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.position.x + bounds.size.x)
	camera.limit_bottom = int(bounds.position.y + bounds.size.y)

func _unhandled_input(event):
	# ESC opens the pause menu during normal gameplay. When paused or when the
	# inventory is open, those UIs run with PROCESS_MODE_ALWAYS and handle ESC
	# themselves (consuming the event), while this node is frozen by the pause.
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func _on_exit_reached(target_level_path: String):
	# Prefer the exit's own destination; fall back to the level's next_level_path
	# for older single-exit levels that don't set it per-exit.
	var dest = target_level_path if target_level_path != "" else next_level_path
	if dest != "":
		# Carry the player's progress (HP, coins, inventory) into the destination.
		GameState.save_player(player)
		# Remember which level we left from so the destination can spawn the
		# player at the exit that leads back here.
		GameState.from_level_path = _level_id
		# Fade to black, swap scenes, then fade back in.
		SceneTransition.change_scene(dest)
	elif is_final_level:
		# Final level cleared — finish the game.
		win_screen.visible = true
		get_tree().paused = true
		
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
func _on_collectible_collected(item_id, node):
	player.collect_item(item_id)
	GameState.mark_object(_level_id, _object_id(node), "gone")

# handle weapon pickup
func _on_weapon_collected(weapon_id, props, node):
	player.collect_weapon(weapon_id, props)
	GameState.mark_object(_level_id, _object_id(node), "gone")

# handle armor pickup
func _on_armor_collected(armor_id, props, node):
	player.collect_armor(armor_id, props)
	GameState.mark_object(_level_id, _object_id(node), "gone")

# Handle coin collection
func _on_coin_collected(value, node):
	player.collect_coins(value)
	GameState.mark_object(_level_id, _object_id(node), "gone")

# Handle chest opening — rewards the player with the coins inside
func _on_chest_opened(coin_reward, node):
	player.collect_coins(coin_reward)
	GameState.mark_object(_level_id, _object_id(node), "opened")

# Handle enemy defeat — record it so the enemy stays gone on re-entry
func _on_enemy_died(node):
	GameState.mark_object(_level_id, _object_id(node), "gone")

# A stable identifier for a world object: its path relative to the level root.
func _object_id(node: Node) -> String:
	return str(get_path_to(node))

# Reapply persisted world state from a previous visit to this level.
func _apply_level_state() -> void:
	var state: Dictionary = GameState.get_level_state(_level_id)
	if state.is_empty():
		return

	# Consumed pickups and defeated enemies are simply removed.
	for group in ["Collectibles", "Coins", "Weapons", "ArmorPickups", "Enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			if state.get(_object_id(node), "") == "gone":
				node.queue_free()

	# Opened chests are restored to their opened appearance.
	for chest in get_tree().get_nodes_in_group("Chests"):
		if state.get(_object_id(chest), "") == "opened":
			chest.set_opened()

# Spawn the player at the exit that leads back to the level they came from, so
# travelling between two levels is symmetric (e.g. returning to level 1 from
# level 2 places the player at level 1's exit, not its default start point).
func _position_player_at_entry() -> void:
	if GameState.from_level_path == "":
		return

	for exit in get_tree().get_nodes_in_group("Exit"):
		if exit.target_level_path == GameState.from_level_path:
			player.global_position = exit.global_position
			player.velocity = Vector2.ZERO
			# Don't let the exit fire until the player walks out of it first.
			exit.disarm()
			break

	# Consume it so a later death/respawn or re-entry doesn't reuse it.
	GameState.from_level_path = ""
