extends Control

# Reference to the inventory resource
var inventory: Inventory
var player: Player = null

# Item grid configuration
const GRID_COLUMNS = 7
const GRID_ROWS = 4
const TOTAL_SLOTS = GRID_COLUMNS * GRID_ROWS
# Number of weapon cells in the weapon section
const WEAPON_SLOTS = 4

# Pre-created cell pools (reused across refreshes)
var slots = []          # item cells
var weapon_slots = []    # weapon cells

# Combined, ordered list of currently-filled cells used for focus/navigation.
# Each entry: { "kind": "item"|"weapon", "slot": Panel, "id": String }
var focus_cells = []
var current_focus_index = 0

# Slot border styles
var normal_style: StyleBoxFlat
var selected_style: StyleBoxFlat
var equipped_style: StyleBoxFlat

@onready var item_grid = $PanelContainer/MarginContainer/VBoxContainer/ItemGrid
@onready var weapon_grid = $PanelContainer/MarginContainer/VBoxContainer/WeaponGrid
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

	# Build the slot styles (normal + selected highlight + equipped marker)
	normal_style = slot_template.get_theme_stylebox("panel").duplicate()
	selected_style = normal_style.duplicate()
	selected_style.border_width_left = 3
	selected_style.border_width_top = 3
	selected_style.border_width_right = 3
	selected_style.border_width_bottom = 3
	selected_style.border_color = Color(1, 0.85, 0.2)

	equipped_style = normal_style.duplicate()
	equipped_style.border_width_left = 3
	equipped_style.border_width_top = 3
	equipped_style.border_width_right = 3
	equipped_style.border_width_bottom = 3
	equipped_style.border_color = Color(0.2, 0.9, 0.3)

	# Pre-create the fixed grids of slots
	_build_slots()

	# Connect close button
	close_button.pressed.connect(toggle_visibility)

func _build_slots():
	for i in range(TOTAL_SLOTS):
		var slot = slot_template.duplicate()
		slot.visible = true
		item_grid.add_child(slot)
		slot.gui_input.connect(_on_item_slot_gui_input.bind(i))
		slots.append(slot)

	for i in range(WEAPON_SLOTS):
		var slot = slot_template.duplicate()
		slot.visible = true
		weapon_grid.add_child(slot)
		slot.gui_input.connect(_on_weapon_slot_gui_input.bind(i))
		weapon_slots.append(slot)

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
		if inventory.weapons_changed.is_connected(_on_inventory_changed):
			inventory.weapons_changed.disconnect(_on_inventory_changed)

	# Connect to new inventory
	inventory = new_inventory
	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.item_used.connect(_on_item_used)
	inventory.weapons_changed.connect(_on_inventory_changed)

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
		if not focus_cells.is_empty():
			set_focus(0)

func _on_inventory_changed():
	refresh_ui()

func _on_item_used(_item_id: String):
	# Just refresh the UI after item usage
	refresh_ui()

func refresh_ui():
	focus_cells.clear()

	# Reset every cell to empty
	for slot in slots:
		_clear_slot(slot)
	for slot in weapon_slots:
		_clear_slot(slot)

	# No inventory yet
	if not inventory:
		return

	# Fill item cells, in order
	var items = inventory.get_items()
	var slot_index = 0
	for item_id in items.keys():
		if slot_index >= slots.size():
			break  # Out of room in the grid

		var slot = slots[slot_index]
		_fill_slot(slot, inventory.get_item_icon(item_id), str(items[item_id]), inventory.get_item_color(item_id))
		focus_cells.append({"kind": "item", "slot": slot, "id": item_id})
		slot_index += 1

	# Fill weapon cells, in order. Equipped weapon shows an "E" marker.
	var weapons = inventory.get_weapons()
	var weapon_index = 0
	for weapon_id in weapons.keys():
		if weapon_index >= weapon_slots.size():
			break

		var slot = weapon_slots[weapon_index]
		# Ranged weapons show their remaining ammo; melee weapons show "E" when
		# equipped. Equipped state is also reflected by the cell border.
		var marker = ""
		if inventory.is_weapon_ranged(weapon_id):
			marker = "x%d" % inventory.get_weapon_count(weapon_id)
		elif inventory.is_weapon_equipped(weapon_id):
			marker = "E"
		_fill_slot(slot, inventory.get_weapon_icon(weapon_id), marker)
		focus_cells.append({"kind": "weapon", "slot": slot, "id": weapon_id})
		weapon_index += 1

	# Update focus / usage hint
	if focus_cells.is_empty():
		description_label.text = ""
		usage_hint.visible = false
	elif visible:
		current_focus_index = clamp(current_focus_index, 0, focus_cells.size() - 1)
		set_focus(current_focus_index)

func _clear_slot(slot):
	slot.get_node("Icon").texture = null
	slot.get_node("Icon").modulate = Color.WHITE
	slot.get_node("Count").text = ""
	slot.add_theme_stylebox_override("panel", normal_style)

func _fill_slot(slot, texture: Texture2D, count_text: String, tint: Color = Color.WHITE):
	slot.get_node("Icon").texture = texture
	slot.get_node("Icon").modulate = tint
	slot.get_node("Count").text = count_text

func set_focus(index: int):
	if focus_cells.is_empty():
		description_label.text = ""
		usage_hint.visible = false
		return

	# Validate index
	index = clamp(index, 0, focus_cells.size() - 1)
	current_focus_index = index

	# Highlight: selected cell wins; otherwise an equipped weapon keeps a marker.
	for i in range(focus_cells.size()):
		var cell = focus_cells[i]
		var style = normal_style
		if i == index:
			style = selected_style
		elif cell.kind == "weapon" and inventory.is_weapon_equipped(cell.id):
			style = equipped_style
		cell.slot.add_theme_stylebox_override("panel", style)

	# Show the selected cell's description and the appropriate hint.
	var focused = focus_cells[index]
	if focused.kind == "item":
		description_label.text = inventory.get_item_description(focused.id)
		if inventory.is_item_usable(focused.id):
			usage_hint.text = "Left-click or E to use"
			usage_hint.add_theme_color_override("font_color", Color(0, 1, 0))
			usage_hint.visible = true
		else:
			usage_hint.visible = false
	else:
		var w = inventory.weapons[focused.id]
		if inventory.is_weapon_ranged(focused.id):
			description_label.text = "%s\nDMG %s  ·  x%s left" % [
				inventory.get_weapon_description(focused.id),
				str(w.get("damage", 1)),
				str(inventory.get_weapon_count(focused.id))
			]
		else:
			description_label.text = "%s\nDMG %s  ·  SPD %s" % [
				inventory.get_weapon_description(focused.id),
				str(w.get("damage", 1)),
				str(w.get("attack_speed", 1.0))
			]
		if inventory.is_weapon_equipped(focused.id):
			usage_hint.text = "Left-click or E to unequip"
		else:
			usage_hint.text = "Left-click or E to equip"
		usage_hint.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		usage_hint.visible = true

# Activate the focused cell: use the item, or equip/unequip the weapon.
func _activate(index: int):
	if index < 0 or index >= focus_cells.size():
		return
	var cell = focus_cells[index]
	if cell.kind == "item":
		if inventory.can_use_item(cell.id):
			inventory.use_item(cell.id)
	else:
		inventory.toggle_equip_weapon(cell.id)

# Map a cell Panel back to its index in the focus list (-1 if not filled).
func _focus_index_for_slot(slot) -> int:
	for i in range(focus_cells.size()):
		if focus_cells[i].slot == slot:
			return i
	return -1

func _on_item_slot_gui_input(event: InputEvent, slot_index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var fi = _focus_index_for_slot(slots[slot_index])
		if fi != -1:
			set_focus(fi)
			_activate(fi)

func _on_weapon_slot_gui_input(event: InputEvent, slot_index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var fi = _focus_index_for_slot(weapon_slots[slot_index])
		if fi != -1:
			set_focus(fi)
			_activate(fi)

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
	elif focus_cells.is_empty():
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
		_activate(current_focus_index)
		get_viewport().set_input_as_handled()
