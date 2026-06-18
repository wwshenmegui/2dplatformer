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
var equipped_melee_id := ""
var equipped_ranged_id := ""
var armors := {}
var equipped_armor := {}

# Snapshot the player's current progress before changing levels.
func save_player(player) -> void:
	has_state = true
	current_hp = player.current_hp
	coins = player.coins
	inventory_items = player.inventory.items.duplicate(true)
	weapons = player.inventory.weapons.duplicate(true)
	equipped_melee_id = player.inventory.equipped_melee_id
	equipped_ranged_id = player.inventory.equipped_ranged_id
	armors = player.inventory.armors.duplicate(true)
	equipped_armor = player.inventory.equipped_armor.duplicate(true)

# Apply previously saved progress onto a newly instanced player.
func load_into_player(player) -> void:
	player.current_hp = current_hp
	player.coins = coins
	player.inventory.items = inventory_items.duplicate(true)
	player.inventory.weapons = weapons.duplicate(true)
	player.inventory.equipped_melee_id = equipped_melee_id
	player.inventory.equipped_ranged_id = equipped_ranged_id
	player.inventory.armors = armors.duplicate(true)
	player.inventory.equipped_armor = equipped_armor.duplicate(true)

# Clear carried-over state so a fresh playthrough starts from scratch.
func reset() -> void:
	has_state = false
	current_hp = 0
	coins = 0
	inventory_items = {}
	weapons = {}
	equipped_melee_id = ""
	equipped_ranged_id = ""
	armors = {}
	equipped_armor = {}
