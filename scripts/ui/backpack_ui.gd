extends Control

# Reference to the inventory resource
var inventory: Inventory
var player: Player = null

# Grid configuration
const GRID_COLUMNS = 7
const GRID_ROWS = 4
const TOTAL_SLOTS = GRID_COLUMNS * GRID_ROWS

# All slot panels in the grid (created once, reused)
var slots = []
# Slots currently holding an item: [{ "slot", "item_id", "can_use" }]
var item_slots = []
var current_focus_index = 0

# Slot border styles
var normal_style: StyleBoxFlat
var selected_style: StyleBoxFlat

@onready var item_grid = $PanelContainer/MarginContainer/VBoxContainer/ItemGrid
@onready var slot_template = $SlotTemplate
@onready var description_label = $PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var usage_hint = $PanelContainer/MarginContainer/VBoxContainer/UsageHint
@onready var coin_icon = $PanelContainer/MarginContainer/VBoxContainer/CoinsDisplay/CoinIcon
@onready var coins_label = $PanelContainer/MarginContainer/VBoxContainer/CoinsDisplay/CoinsLabel
@onready var close_button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

func _ready():
	# Make this node pause-independent
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Hide the UI initially
	visible = false

	# Hide the template
	slot_template.visible = false

	# Build the slot styles (normal + selected highlight)
	normal_style = slot_template.get_theme_stylebox("panel").duplicate()
	selected_style = normal_style.duplicate()
	selected_style.border_width_left = 3
	selected_style.border_width_top = 3
	selected_style.border_width_right = 3
	selected_style.border_width_bottom = 3
	selected_style.border_color = Color(1, 0.85, 0.2)

	# Pre-create the fixed grid of slots
	_build_slots()

	# Connect close button
	close_button.pressed.connect(toggle_visibility)

func _build_slots():
	for i in range(TOTAL_SLOTS):
		var slot = slot_template.duplicate()
		slot.visible = true
		item_grid.add_child(slot)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		slots.append(slot)

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

	# Show the coin icon now that we have item data
	coin_icon.texture = inventory.get_item_icon("coin")

	# Get the player reference (owner of the inventory)
	if inventory and inventory.owner:
		set_player(inventory.owner)

	# Initialize UI
	refresh_ui()

func update_coins_display(coin_amount: int):
	if coins_label:
		coins_label.text = "x " + str(coin_amount)

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
		if not item_slots.is_empty():
			set_focus(0)

func _on_inventory_changed():
	refresh_ui()

func _on_item_used(_item_id: String):
	# Just refresh the UI after item usage
	refresh_ui()

func refresh_ui():
	item_slots.clear()

	# Reset every slot to empty
	for slot in slots:
		_clear_slot(slot)

	# No inventory yet
	if not inventory:
		return

	# Fill slots with items, in order
	var items = inventory.get_items()
	var slot_index = 0
	for item_id in items.keys():
		if slot_index >= slots.size():
			break  # Out of room in the grid

		var count = items[item_id]
		var can_use = inventory.can_use_item(item_id)
		var slot = slots[slot_index]

		_fill_slot(slot, item_id, count)

		item_slots.append({
			"slot": slot,
			"item_id": item_id,
			"can_use": can_use
		})
		slot_index += 1

	# Update focus / usage hint
	if item_slots.is_empty():
		description_label.text = ""
		usage_hint.visible = false
	elif visible:
		current_focus_index = clamp(current_focus_index, 0, item_slots.size() - 1)
		set_focus(current_focus_index)

func _clear_slot(slot):
	slot.get_node("Icon").texture = null
	slot.get_node("Count").text = ""
	slot.add_theme_stylebox_override("panel", normal_style)

func _fill_slot(slot, item_id: String, count: int):
	slot.get_node("Icon").texture = inventory.get_item_icon(item_id)
	slot.get_node("Count").text = str(count)

func set_focus(index: int):
	if item_slots.is_empty():
		description_label.text = ""
		usage_hint.visible = false
		return

	# Validate index
	index = clamp(index, 0, item_slots.size() - 1)
	current_focus_index = index

	# Highlight the selected slot only
	for i in range(item_slots.size()):
		var style = selected_style if i == index else normal_style
		item_slots[i].slot.add_theme_stylebox_override("panel", style)

	# Show the selected item's description
	var item_id = item_slots[index].item_id
	description_label.text = inventory.get_item_description(item_id)

	# Update the usage hint for the selected item
	if inventory.is_item_usable(item_id):
		usage_hint.text = "Left-click or E to use"
		usage_hint.add_theme_color_override("font_color", Color(0, 1, 0))  # Green
		usage_hint.visible = true
	else:
		usage_hint.visible = false

# Use the item in the given slot if it can be used now. Quietly does
# nothing when the item is missing or unusable (e.g. health already full).
func _try_use_item(index: int):
	if index < 0 or index >= item_slots.size():
		return
	var item_id = item_slots[index].item_id
	if inventory.can_use_item(item_id):
		inventory.use_item(item_id)

func _on_slot_gui_input(event: InputEvent, slot_index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Only react to slots that hold an item
		if slot_index < item_slots.size():
			set_focus(slot_index)
			# Left-click also uses the item
			_try_use_item(slot_index)

func _input(event):
	if not visible:
		# Don't allow opening the inventory while the game is paused
		# (e.g. the pause menu is up — the tree is only paused by something
		# other than the backpack when the backpack itself is closed).
		if event.is_action_pressed("open_inventory") and not get_tree().paused:
			toggle_visibility()
		return

	# Handle input only when visible.
	# Both the inventory key and ESC close the backpack and return to the game.
	if event.is_action_pressed("open_inventory") or event.is_action_pressed("ui_cancel"):
		toggle_visibility()
		get_viewport().set_input_as_handled()
	elif item_slots.is_empty():
		return
	elif event.is_action_pressed("ui_right"):
		set_focus(current_focus_index + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		set_focus(current_focus_index - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		set_focus(current_focus_index + GRID_COLUMNS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		set_focus(current_focus_index - GRID_COLUMNS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_try_use_item(current_focus_index)
		get_viewport().set_input_as_handled()
