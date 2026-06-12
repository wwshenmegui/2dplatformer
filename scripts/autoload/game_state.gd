extends Node

# Persists the player's progress (HP, coins, inventory) across level
# transitions within a single playthrough. Registered as the "GameState"
# autoload singleton, so it survives change_scene_to_file().

# Whether there is carried-over state to apply to a freshly loaded player.
var has_state := false
var current_hp := 0
var coins := 0
var inventory_items := {}
var weapons := {}
var equipped_weapon_id := ""

# Snapshot the player's current progress before changing levels.
func save_player(player) -> void:
	has_state = true
	current_hp = player.current_hp
	coins = player.coins
	inventory_items = player.inventory.items.duplicate(true)
	weapons = player.inventory.weapons.duplicate(true)
	equipped_weapon_id = player.inventory.equipped_weapon_id

# Apply previously saved progress onto a newly instanced player.
func load_into_player(player) -> void:
	player.current_hp = current_hp
	player.coins = coins
	player.inventory.items = inventory_items.duplicate(true)
	player.inventory.weapons = weapons.duplicate(true)
	player.inventory.equipped_weapon_id = equipped_weapon_id

# Clear carried-over state so a fresh playthrough starts from scratch.
func reset() -> void:
	has_state = false
	current_hp = 0
	coins = 0
	inventory_items = {}
	weapons = {}
	equipped_weapon_id = ""
