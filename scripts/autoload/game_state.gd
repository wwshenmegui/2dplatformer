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

# Per-level world state that should survive leaving and re-entering a level
# within a single playthrough (opened chests, defeated enemies, picked-up
# collectibles, etc). Keyed by the level's scene path, each value is a
# dictionary of object_id -> state string (e.g. "gone" / "opened").
var level_states := {}

# The scene path of the level the player just left through an exit. The
# destination level uses this to spawn the player at the exit that leads back,
# so travelling between levels is symmetric.
var from_level_path := ""

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

# Record that a world object in a level changed state (was consumed, opened,
# defeated, ...) so the change is reapplied when the level is re-entered.
func mark_object(level_path: String, object_id: String, state: String) -> void:
	if not level_states.has(level_path):
		level_states[level_path] = {}
	level_states[level_path][object_id] = state

# The recorded object states for a level (empty if it has never been visited).
func get_level_state(level_path: String) -> Dictionary:
	return level_states.get(level_path, {})

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
	level_states = {}
	from_level_path = ""
