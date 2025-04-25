extends Resource

class_name Inventory

signal inventory_changed
signal item_used(item_id)

# Dictionary to store items and quantities
var items = {}

# Dictionary to map item IDs to their properties
var item_properties = {
	"health_potion": {
		"name": "Health Potion",
		"description": "Restores 1 health point",
		"usable": true,
		"effect": "heal",
		"effect_value": 1
	},
	"coin": {
		"name": "Coin",
		"description": "Currency",
		"usable": false
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
