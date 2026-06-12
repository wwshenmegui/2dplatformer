extends Resource

class_name Inventory

signal inventory_changed
signal item_used(item_id)
# Weapon system signals
signal weapons_changed
# Emitted whenever the equipped weapon changes. weapon_id is "" when nothing
# is equipped (i.e. the player unequipped their weapon).
signal weapon_equipped(weapon_id)

# Source textures for item icons (atlases with 16x16 frames)
const FRUIT_TEXTURE = preload("res://assets/textures/fruit.png")
const COIN_TEXTURE = preload("res://assets/textures/coin.png")

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
# The currently equipped weapon id, or "" when nothing is equipped.
var equipped_weapon_id = ""

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

# --- Weapon system ---

func add_weapon(weapon_id: String, props: Dictionary) -> void:
	weapons[weapon_id] = props
	weapons_changed.emit()

func has_weapon(weapon_id: String) -> bool:
	return weapons.has(weapon_id)

func get_weapons() -> Dictionary:
	return weapons.duplicate()

func is_weapon_equipped(weapon_id: String) -> bool:
	return equipped_weapon_id == weapon_id

func get_equipped_weapon_id() -> String:
	return equipped_weapon_id

# Toggle the equipped state of a weapon. Equipping a weapon while another is
# equipped swaps to the new one; selecting the equipped weapon unequips it.
func toggle_equip_weapon(weapon_id: String) -> void:
	if not weapons.has(weapon_id):
		return

	if equipped_weapon_id == weapon_id:
		equipped_weapon_id = ""
	else:
		equipped_weapon_id = weapon_id

	weapon_equipped.emit(equipped_weapon_id)
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
