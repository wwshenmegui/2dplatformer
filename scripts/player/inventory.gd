extends Resource

class_name Inventory

signal inventory_changed
signal item_used(item_id)
# Weapon system signals
signal weapons_changed
# Armor system signal — emitted when armor is picked up or (un)equipped.
signal armor_changed

# Source textures for item icons (atlases with 16x16 frames)
const FRUIT_TEXTURE = preload("res://assets/textures/fruit.png")
const COIN_TEXTURE = preload("res://assets/textures/coin.png")
# Armor atlas (1024x1024, 2x2 grid of 512px frames: head/chest/hand/foot)
const ARMORS_TEXTURE = preload("res://assets/textures/player/equipments/armors/armors.png")

# Dictionary to store items and quantities
var items = {}

# Dictionary to map item IDs to their properties
var item_properties = {
	"health_potion": {
		"name": "Health Potion",
		"description": "Restores 1 health point",
		"usable": true,
		"effect": "heal",
		"effect_value": 1,
		"icon_texture": FRUIT_TEXTURE,
		"icon_region": Rect2(0, 0, 16, 16)
	},
	"coin": {
		"name": "Coin",
		"description": "Currency",
		"usable": false,
		"icon_texture": COIN_TEXTURE,
		"icon_region": Rect2(0, 0, 16, 16)
	}
}

# Weapons the player has picked up: weapon_id -> properties dictionary
# (name, description, attack_speed, damage, icon_texture).
var weapons = {}
# Currently equipped weapon ids per category, or "" when that slot is empty.
# A melee and a ranged weapon can be equipped at the same time.
var equipped_melee_id = ""
var equipped_ranged_id = ""

# Armor the player has picked up: armor_id -> properties dictionary
# (name, description, slot, armor_value, icon_texture).
var armors = {}
# The equipped armor id for each body slot, or "" when that slot is empty.
var equipped_armor = {"head": "", "chest": "", "hand": "", "foot": ""}

# Built-in armor registry. World pickups (scenes/elements/armor.tscn) supply
# their own props, but these defaults let armor be seeded for a fresh player.
var armor_properties = {
	"head_armor": {
		"name": "Iron Helm",
		"description": "Protects the head.",
		"slot": "head",
		"armor_value": 1,
		"icon_texture": ARMORS_TEXTURE,
		"icon_region": Rect2(0, 0, 512, 512)
	},
	"chest_armor": {
		"name": "Iron Cuirass",
		"description": "Protects the chest.",
		"slot": "chest",
		"armor_value": 2,
		"icon_texture": ARMORS_TEXTURE,
		"icon_region": Rect2(512, 0, 512, 512)
	},
	"hand_armor": {
		"name": "Iron Gauntlets",
		"description": "Protects the hands.",
		"slot": "hand",
		"armor_value": 1,
		"icon_texture": ARMORS_TEXTURE,
		"icon_region": Rect2(0, 512, 512, 512)
	},
	"foot_armor": {
		"name": "Iron Boots",
		"description": "Protects the feet.",
		"slot": "foot",
		"armor_value": 1,
		"icon_texture": ARMORS_TEXTURE,
		"icon_region": Rect2(512, 512, 512, 512)
	}
}

# Reference to the owner of this inventory (typically the player)
var owner = null

func set_owner(new_owner):
	owner = new_owner

func add_item(item_id: String, quantity: int = 1):
	if items.has(item_id):
		items[item_id] += quantity
	else:
		items[item_id] = quantity
	
	inventory_changed.emit()
	return true

func remove_item(item_id: String, quantity: int = 1):
	if not items.has(item_id):
		return false
	
	if items[item_id] <= quantity:
		items.erase(item_id)
	else:
		items[item_id] -= quantity
	
	inventory_changed.emit()
	return true

func get_item_count(item_id: String) -> int:
	if items.has(item_id):
		return items[item_id]
	return 0

func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity

func get_items() -> Dictionary:
	return items.duplicate()

func get_item_name(item_id: String) -> String:
	if item_properties.has(item_id):
		return item_properties[item_id].name
	return item_id.capitalize()

func get_item_description(item_id: String) -> String:
	if item_properties.has(item_id):
		return item_properties[item_id].description
	return ""

func get_item_icon(item_id: String) -> Texture2D:
	if item_properties.has(item_id) and item_properties[item_id].has("icon_texture"):
		var props = item_properties[item_id]
		var atlas = AtlasTexture.new()
		atlas.atlas = props.icon_texture
		atlas.region = props.get("icon_region", Rect2(0, 0, 16, 16))
		return atlas
	return null

# Tint applied to an item's icon in the UI (white when none is specified).
func get_item_color(item_id: String) -> Color:
	if item_properties.has(item_id):
		return item_properties[item_id].get("icon_modulate", Color.WHITE)
	return Color.WHITE

func is_item_usable(item_id: String) -> bool:
	if item_properties.has(item_id):
		return item_properties[item_id].get("usable", false)
	return false

func get_item_effect(item_id: String) -> Dictionary:
	if item_properties.has(item_id):
		var effect = item_properties[item_id].get("effect", "")
		var effect_value = item_properties[item_id].get("effect_value", 0)
		return {"effect": effect, "value": effect_value}
	return {"effect": "", "value": 0}

func can_use_item(item_id: String) -> bool:
	# First check if we have the item and it's marked as usable
	if not has_item(item_id) or not is_item_usable(item_id):
		return false
	
	# If it's a health potion, check if player can be healed
	if item_id == "health_potion" and owner and owner.has_method("can_heal"):
		return owner.can_heal()
	
	# Default to true for other usable items
	return true

func use_item(item_id: String) -> bool:
	# Check if the item can be used in the current context
	if not can_use_item(item_id):
		return false
		
	# Remove one of the item
	remove_item(item_id, 1)
	
	# Emit signal that the item was used
	item_used.emit(item_id)

	return true

# Drop one unit of an item from the backpack.
func discard_item(item_id: String) -> bool:
	return remove_item(item_id, 1)

# --- Weapon system ---

func add_weapon(weapon_id: String, props: Dictionary) -> void:
	# Ranged (ammo-based) weapons stack: picking up another of the same kind adds
	# to its count rather than replacing it. Melee weapons are unique.
	if weapons.has(weapon_id) and is_weapon_ranged(weapon_id):
		weapons[weapon_id]["count"] = get_weapon_count(weapon_id) + props.get("count", 1)
	else:
		weapons[weapon_id] = props
	weapons_changed.emit()

func has_weapon(weapon_id: String) -> bool:
	return weapons.has(weapon_id)

# --- Ranged weapons (throwables) ---

func is_weapon_ranged(weapon_id: String) -> bool:
	return weapons.has(weapon_id) and weapons[weapon_id].get("type", "melee") == "ranged"

# Remaining ammo for a ranged weapon (0 if it isn't held).
func get_weapon_count(weapon_id: String) -> int:
	if weapons.has(weapon_id):
		return weapons[weapon_id].get("count", 1)
	return 0

# Spend one unit of a ranged weapon's ammo. Returns false when none is left.
# Using the last unit removes the weapon and unequips it.
func consume_weapon_ammo(weapon_id: String) -> bool:
	if not weapons.has(weapon_id):
		return false

	var count = get_weapon_count(weapon_id) - 1
	if count <= 0:
		if equipped_ranged_id == weapon_id:
			equipped_ranged_id = ""
		weapons.erase(weapon_id)
	else:
		weapons[weapon_id]["count"] = count

	weapons_changed.emit()
	return true

func get_weapons() -> Dictionary:
	return weapons.duplicate()

# All held weapons of a given category ("melee" or "ranged").
func get_weapons_by_type(weapon_type: String) -> Dictionary:
	var result = {}
	for id in weapons.keys():
		if weapons[id].get("type", "melee") == weapon_type:
			result[id] = weapons[id]
	return result

func get_equipped_melee_id() -> String:
	return equipped_melee_id

func get_equipped_ranged_id() -> String:
	return equipped_ranged_id

func is_weapon_equipped(weapon_id: String) -> bool:
	if is_weapon_ranged(weapon_id):
		return equipped_ranged_id == weapon_id
	return equipped_melee_id == weapon_id

# Toggle the equipped state of a weapon within its own category. Equipping a
# weapon swaps out whatever shared its category slot; re-selecting it unequips.
func toggle_equip_weapon(weapon_id: String) -> void:
	if not weapons.has(weapon_id):
		return

	if is_weapon_ranged(weapon_id):
		equipped_ranged_id = "" if equipped_ranged_id == weapon_id else weapon_id
	else:
		equipped_melee_id = "" if equipped_melee_id == weapon_id else weapon_id

	weapons_changed.emit()

func get_weapon_name(weapon_id: String) -> String:
	if weapons.has(weapon_id):
		return weapons[weapon_id].get("name", weapon_id.capitalize())
	return weapon_id.capitalize()

func get_weapon_description(weapon_id: String) -> String:
	if weapons.has(weapon_id):
		return weapons[weapon_id].get("description", "")
	return ""

func get_weapon_icon(weapon_id: String) -> Texture2D:
	if weapons.has(weapon_id):
		return weapons[weapon_id].get("icon_texture", null)
	return null

# --- Armor system ---

# Store a picked-up (or seeded) armor piece. Armor is unique per id.
func add_armor(armor_id: String, props: Dictionary) -> void:
	armors[armor_id] = props
	armor_changed.emit()

func has_armor(armor_id: String) -> bool:
	return armors.has(armor_id)

func get_armors() -> Dictionary:
	return armors.duplicate()

# All held armor pieces that fit a given body slot.
func get_armors_by_slot(slot: String) -> Dictionary:
	var result = {}
	for id in armors.keys():
		if armors[id].get("slot", "") == slot:
			result[id] = armors[id]
	return result

func is_armor_equipped(armor_id: String) -> bool:
	if not armors.has(armor_id):
		return false
	var slot = armors[armor_id].get("slot", "")
	return equipped_armor.get(slot, "") == armor_id

# Toggle an armor piece in its body slot. Equipping swaps out whatever occupied
# that slot; re-selecting the equipped piece unequips it.
func toggle_equip_armor(armor_id: String) -> void:
	if not armors.has(armor_id):
		return
	var slot = armors[armor_id].get("slot", "")
	if not equipped_armor.has(slot):
		return
	equipped_armor[slot] = "" if equipped_armor[slot] == armor_id else armor_id
	armor_changed.emit()

func get_armor_name(armor_id: String) -> String:
	if armors.has(armor_id):
		return armors[armor_id].get("name", armor_id.capitalize())
	return armor_id.capitalize()

func get_armor_description(armor_id: String) -> String:
	if armors.has(armor_id):
		return armors[armor_id].get("description", "")
	return ""

func get_armor_value(armor_id: String) -> int:
	if armors.has(armor_id):
		return armors[armor_id].get("armor_value", 0)
	return 0

func get_armor_icon(armor_id: String) -> Texture2D:
	if not armors.has(armor_id):
		return null
	var props = armors[armor_id]
	var tex = props.get("icon_texture", null)
	if tex == null:
		return null
	# Armor icons may be a region of an atlas; wrap them when a region is given.
	if props.has("icon_region"):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = props.get("icon_region")
		return atlas
	return tex

# --- Derived stats ---

# Attack power: the equipped melee weapon's damage, or the owner's unarmed base.
func get_total_attack() -> int:
	if equipped_melee_id != "" and weapons.has(equipped_melee_id):
		return weapons[equipped_melee_id].get("damage", 0)
	if owner and "base_attack_damage" in owner:
		return owner.base_attack_damage
	return 0

# Total damage mitigation from all currently equipped armor pieces.
func get_total_armor() -> int:
	var total = 0
	for slot in equipped_armor.keys():
		var armor_id = equipped_armor[slot]
		if armor_id != "" and armors.has(armor_id):
			total += armors[armor_id].get("armor_value", 0)
	return total
