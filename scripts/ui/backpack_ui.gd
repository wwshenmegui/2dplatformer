extends Control

# Reference to the inventory resource
var inventory: Inventory

@onready var item_container = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ItemContainer
@onready var item_label_template = $ItemLabelTemplate

func _ready():
	# Make this node pause-independent
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Hide the UI initially
	visible = false
	
	# Hide the template
	item_label_template.visible = false

func set_inventory(new_inventory: Inventory):
	# Disconnect from old inventory if exists
	if inventory:
		inventory.inventory_changed.disconnect(_on_inventory_changed)
	
	# Connect to new inventory
	inventory = new_inventory
	inventory.inventory_changed.connect(_on_inventory_changed)
	
	# Initialize UI
	refresh_ui()

func toggle_visibility():
	visible = !visible
	
	# Pause/unpause the game when inventory is open/closed
	get_tree().paused = visible

func _on_inventory_changed():
	refresh_ui()

func refresh_ui():
	# Clear existing items
	for child in item_container.get_children():
		if child != item_label_template:
			child.queue_free()
	
	# No inventory yet
	if not inventory:
		return
	
	# Get all items from inventory
	var items = inventory.get_items()
	
	# Add items to the UI
	for item_id in items.keys():
		var count = items[item_id]
		
		# Create new label from template
		var new_label = item_label_template.duplicate()
		new_label.visible = true
		new_label.text = item_id.capitalize() + " x" + str(count)
		
		item_container.add_child(new_label)
	
	# Show "Empty" message if no items
	if items.is_empty():
		var empty_label = item_label_template.duplicate()
		empty_label.visible = true
		empty_label.text = "Backpack is empty"
		item_container.add_child(empty_label)

func _input(event):
	if event.is_action_pressed("open_inventory"):
		toggle_visibility()
