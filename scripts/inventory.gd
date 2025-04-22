extends Resource

class_name Inventory

signal inventory_changed

# Dictionary to store items and quantities
var items = {}

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
