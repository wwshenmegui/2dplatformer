extends Control

# Reference to the inventory resource
var inventory: Inventory
var player: Player = null

# Keep track of UI elements for items
var item_buttons = []
var current_focus_index = 0

@onready var item_container = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ItemContainer
@onready var item_button_template = $ItemButtonTemplate
@onready var description_label = $PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var usage_hint = $PanelContainer/MarginContainer/VBoxContainer/UsageHint
@onready var coins_label = $PanelContainer/MarginContainer/VBoxContainer/CoinsLabel
@onready var close_button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

func _ready():
	# Make this node pause-independent
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Hide the UI initially
	visible = false
	
	# Hide the template
	item_button_template.visible = false
	
	# Connect close button
	close_button.pressed.connect(toggle_visibility)
	
func set_player(p: Player):
	# Disconnect from old player if exists
	if player and player.coins_changed.is_connected(update_coins_display):
		player.coins_changed.disconnect(update_coins_display)
	
	# Set new player reference
	player = p
	
	# Connect to player signals
	if player:
		# Connect to coins changed signal
		if not player.coins_changed.is_connected(update_coins_display):
			player.coins_changed.connect(update_coins_display)
		
		# Initial update
		update_coins_display(player.coins)

func set_inventory(new_inventory: Inventory):
	# Disconnect from old inventory if exists
	if inventory:
		if inventory.inventory_changed.is_connected(_on_inventory_changed):
			inventory.inventory_changed.disconnect(_on_inventory_changed)
		if inventory.item_used.is_connected(_on_item_used):
			inventory.item_used.disconnect(_on_item_used)
	
	# Connect to new inventory
	inventory = new_inventory
	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.item_used.connect(_on_item_used)
	
	# Get the player reference (owner of the inventory)
	if inventory and inventory.owner:
		set_player(inventory.owner)
	
	# Initialize UI
	refresh_ui()
	
func update_coins_display(coin_amount: int):
	if coins_label:
		coins_label.text = "Coins: " + str(coin_amount)

func toggle_visibility():
	visible = !visible
	
	# Pause/unpause the game when inventory is open/closed
	get_tree().paused = visible
	
	# If we're showing the inventory, update the UI first to ensure fresh state
	if visible:
		# Update coin display
		if player:
			update_coins_display(player.coins)
			
		refresh_ui()  # Make sure we have updated usability status
		if not item_buttons.is_empty():
			set_focus(0)

func _on_inventory_changed():
	refresh_ui()

func _on_item_used(item_id: String):
	# Just refresh the UI after item usage
	refresh_ui()

func refresh_ui():
	# Clear existing items
	for child in item_container.get_children():
		if child != item_button_template:
			child.queue_free()
	
	# Clear the buttons array
	item_buttons.clear()
	
	# No inventory yet
	if not inventory:
		return
	
	# Get all items from inventory
	var items = inventory.get_items()
	
	# Add items to the UI
	for item_id in items.keys():
		var count = items[item_id]
		var is_usable = inventory.is_item_usable(item_id)
		
		# Check in real-time if the item can be used NOW
		var can_use = inventory.can_use_item(item_id)
		
		var item_name = inventory.get_item_name(item_id)
		
		# Create new button from template
		var new_button = item_button_template.duplicate()
		new_button.visible = true
		new_button.text = item_name + " x" + str(count)
		
		# Set button properties based on usability
		if is_usable:
			if can_use:
				new_button.add_theme_color_override("font_color", Color(0, 1, 0))  # Green for usable items
			else:
				new_button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # Gray for unusable items
		
		# Connect the button pressed signal
		new_button.pressed.connect(_on_item_button_pressed.bind(item_buttons.size(), item_id))
		
		item_container.add_child(new_button)
		item_buttons.append({
			"button": new_button, 
			"item_id": item_id,
			"can_use": can_use
		})
	
	# Show "Empty" message if no items
	if items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Backpack is empty"
		item_container.add_child(empty_label)
		
		# Clear description and usage hint
		description_label.text = ""
		usage_hint.visible = false
	elif visible:
		# If currently visible, update the focus
		current_focus_index = clamp(current_focus_index, 0, item_buttons.size() - 1)
		if current_focus_index >= 0:
			set_focus(current_focus_index)

func set_focus(index: int):
	if item_buttons.is_empty():
		description_label.text = ""
		usage_hint.visible = false
		return
	
	# Validate index
	index = clamp(index, 0, item_buttons.size() - 1)
	current_focus_index = index
	
	# Remove focus from all buttons
	for button_data in item_buttons:
		button_data.button.release_focus()
	
	# Set focus on the selected button
	var button_data = item_buttons[index]
	button_data.button.grab_focus()
	
	# Update description
	var item_id = button_data.item_id
	description_label.text = inventory.get_item_description(item_id)
	
	# Get fresh status of whether item can be used (in case player health has changed)
	var is_usable = inventory.is_item_usable(item_id)
	var can_use = inventory.can_use_item(item_id)
	
	# Update button color in real-time
	if is_usable:
		if can_use:
			button_data.button.add_theme_color_override("font_color", Color(0, 1, 0))  # Green
		else:
			button_data.button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # Gray
	
	# Show usage hint
	if is_usable:
		if can_use:
			usage_hint.text = "Press E to use"
			usage_hint.add_theme_color_override("font_color", Color(0, 1, 0))  # Green
		else:
			usage_hint.text = "Cannot use now"
			usage_hint.add_theme_color_override("font_color", Color(1, 0.5, 0.5))  # Red
		usage_hint.visible = true
	else:
		usage_hint.visible = false

func _on_item_button_pressed(index: int, item_id: String):
	set_focus(index)

func _input(event):
	if not visible:
		if event.is_action_pressed("open_inventory"):
			toggle_visibility()
		return
	
	# Handle input only when visible
	if event.is_action_pressed("open_inventory"):
		toggle_visibility()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") and not item_buttons.is_empty():
		set_focus((current_focus_index - 1 + item_buttons.size()) % item_buttons.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") and not item_buttons.is_empty():
		set_focus((current_focus_index + 1) % item_buttons.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not item_buttons.is_empty():
		# Get fresh status before trying to use
		var item_id = item_buttons[current_focus_index].item_id
		var can_use = inventory.can_use_item(item_id)
		
		if can_use:
			inventory.use_item(item_id)
		
		get_viewport().set_input_as_handled()
