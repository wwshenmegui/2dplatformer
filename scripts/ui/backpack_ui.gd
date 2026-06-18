extends Control

# Backpack with two categories — Items and Equipment — and a per-slot detail
# screen for choosing what to equip. Three views share one panel:
#   ITEMS      grid of consumables/materials + Use/Discard actions
#   EQUIPMENT  equipped melee/ranged weapons, the four armor slots, and stats
#   DETAIL     the owned candidates for one equipment slot + Equip/Unequip
enum View { ITEMS, EQUIPMENT, DETAIL }

# Reference to the inventory resource
var inventory: Inventory
var player: Player = null

# Grid capacities (cells are reused across refreshes).
const ITEM_SLOTS = 28
const DETAIL_SLOTS = 14
# The equipment slots, in the order shown, mapped to the categories they pull
# candidates from in the detail view.
const ARMOR_SLOTS = ["head", "chest", "hand", "foot"]

# Cell pools
var item_cells = []      # Panels in ItemGrid
var detail_cells = []    # Panels in DetailGrid
var equip_cells = {}     # slot name -> Panel (melee/range/head/chest/hand/foot)

# Navigation / selection state
var current_view = View.ITEMS
var detail_slot = ""           # which equipment slot the detail view is editing
var item_selected_id = ""      # selected item in the ITEMS view
var detail_selected_id = ""    # selected candidate in the DETAIL view

# Maps a filled cell Panel back to the id it represents, per view.
var item_cell_ids = {}         # Panel -> item_id
var detail_cell_ids = {}       # Panel -> candidate id

# Styles
var normal_style: StyleBoxFlat
var selected_style: StyleBoxFlat
var equipped_style: StyleBoxFlat

@onready var back_button = $PanelContainer/MarginContainer/Root/TopBar/BackButton
@onready var coin_icon = $PanelContainer/MarginContainer/Root/TopBar/CoinsDisplay/CoinIcon
@onready var coins_label = $PanelContainer/MarginContainer/Root/TopBar/CoinsDisplay/CoinsLabel
@onready var item_tab = $PanelContainer/MarginContainer/Root/Tabs/ItemTab
@onready var equipment_tab = $PanelContainer/MarginContainer/Root/Tabs/EquipmentTab
@onready var tabs = $PanelContainer/MarginContainer/Root/Tabs

@onready var items_view = $PanelContainer/MarginContainer/Root/ViewStack/ItemsView
@onready var item_grid = $PanelContainer/MarginContainer/Root/ViewStack/ItemsView/ItemGrid
@onready var description_label = $PanelContainer/MarginContainer/Root/ViewStack/ItemsView/DescriptionLabel
@onready var use_button = $PanelContainer/MarginContainer/Root/ViewStack/ItemsView/ActionRow/UseButton
@onready var discard_button = $PanelContainer/MarginContainer/Root/ViewStack/ItemsView/ActionRow/DiscardButton

@onready var equipment_view = $PanelContainer/MarginContainer/Root/ViewStack/EquipmentView
@onready var stats_label = $PanelContainer/MarginContainer/Root/ViewStack/EquipmentView/CenterCol/StatsLabel

@onready var detail_view = $PanelContainer/MarginContainer/Root/ViewStack/DetailView
@onready var detail_title = $PanelContainer/MarginContainer/Root/ViewStack/DetailView/DetailTitle
@onready var detail_description = $PanelContainer/MarginContainer/Root/ViewStack/DetailView/DetailDescription
@onready var detail_grid = $PanelContainer/MarginContainer/Root/ViewStack/DetailView/DetailGrid
@onready var equip_button = $PanelContainer/MarginContainer/Root/ViewStack/DetailView/EquipButton

@onready var slot_template = $SlotTemplate

func _ready():
	# Pause-independent so it stays interactive while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	slot_template.visible = false

	# Border styles: plain cell, selected (yellow), equipped (green).
	normal_style = slot_template.get_theme_stylebox("panel").duplicate()
	selected_style = _bordered(normal_style, Color(1, 0.85, 0.2))
	equipped_style = _bordered(normal_style, Color(0.2, 0.9, 0.3))

	_build_cells()

	# Top bar / tabs
	back_button.pressed.connect(_on_back_pressed)
	item_tab.pressed.connect(_show_view.bind(View.ITEMS))
	equipment_tab.pressed.connect(_show_view.bind(View.EQUIPMENT))

	# Item action buttons
	use_button.pressed.connect(_on_use_pressed)
	discard_button.pressed.connect(_on_discard_pressed)

	# Equip/unequip button in the detail view
	equip_button.pressed.connect(_on_equip_pressed)

func _bordered(base: StyleBoxFlat, color: Color) -> StyleBoxFlat:
	var s = base.duplicate()
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.border_color = color
	return s

func _build_cells():
	for i in range(ITEM_SLOTS):
		var cell = _new_cell()
		item_grid.add_child(cell)
		cell.gui_input.connect(_on_item_cell_input.bind(cell))
		item_cells.append(cell)

	for i in range(DETAIL_SLOTS):
		var cell = _new_cell()
		detail_grid.add_child(cell)
		cell.gui_input.connect(_on_detail_cell_input.bind(cell))
		detail_cells.append(cell)

	# One equip box per equipment slot, placed in its holder. Clicking a box
	# opens the detail view for that slot.
	var holders = {
		"melee": $PanelContainer/MarginContainer/Root/ViewStack/EquipmentView/LeftCol/MeleeHolder,
		"range": $PanelContainer/MarginContainer/Root/ViewStack/EquipmentView/LeftCol/RangeHolder,
		"head": $PanelContainer/MarginContainer/Root/ViewStack/EquipmentView/RightCol/HeadHolder,
		"chest": $PanelContainer/MarginContainer/Root/ViewStack/EquipmentView/RightCol/ChestHolder,
		"hand": $PanelContainer/MarginContainer/Root/ViewStack/EquipmentView/RightCol/HandHolder,
		"foot": $PanelContainer/MarginContainer/Root/ViewStack/EquipmentView/RightCol/FootHolder,
	}
	for slot in holders.keys():
		var cell = _new_cell()
		holders[slot].add_child(cell)
		cell.gui_input.connect(_on_equip_box_input.bind(slot))
		equip_cells[slot] = cell

func _new_cell() -> Panel:
	var cell = slot_template.duplicate()
	cell.visible = true
	return cell

# --- Wiring ---

func set_player(p: Player):
	if player and player.coins_changed.is_connected(update_coins_display):
		player.coins_changed.disconnect(update_coins_display)
	player = p
	if player:
		if not player.coins_changed.is_connected(update_coins_display):
			player.coins_changed.connect(update_coins_display)
		update_coins_display(player.coins)

func set_inventory(new_inventory: Inventory):
	if inventory:
		if inventory.inventory_changed.is_connected(_on_data_changed):
			inventory.inventory_changed.disconnect(_on_data_changed)
		if inventory.weapons_changed.is_connected(_on_data_changed):
			inventory.weapons_changed.disconnect(_on_data_changed)
		if inventory.armor_changed.is_connected(_on_data_changed):
			inventory.armor_changed.disconnect(_on_data_changed)

	inventory = new_inventory
	inventory.inventory_changed.connect(_on_data_changed)
	inventory.weapons_changed.connect(_on_data_changed)
	inventory.armor_changed.connect(_on_data_changed)

	coin_icon.texture = inventory.get_item_icon("coin")

	if inventory and inventory.owner:
		set_player(inventory.owner)

	_refresh_current_view()

func update_coins_display(coin_amount: int):
	if coins_label:
		coins_label.text = "x " + str(coin_amount)

func _on_data_changed():
	_refresh_current_view()

# --- Open / close & view switching ---

func toggle_visibility():
	visible = !visible
	get_tree().paused = visible
	if visible:
		if player:
			update_coins_display(player.coins)
		_show_view(View.ITEMS)

func _on_back_pressed():
	# In the detail view the arrow returns to the equipment view; elsewhere it
	# closes the backpack.
	if current_view == View.DETAIL:
		_show_view(View.EQUIPMENT)
	else:
		toggle_visibility()

func _show_view(view: int):
	current_view = view
	items_view.visible = view == View.ITEMS
	equipment_view.visible = view == View.EQUIPMENT
	detail_view.visible = view == View.DETAIL
	# Category tabs are hidden while drilling into a single slot.
	tabs.visible = view != View.DETAIL
	_update_tab_highlight()
	_refresh_current_view()

func _update_tab_highlight():
	var active = Color(1, 0.85, 0.2)
	var inactive = Color(0.6, 0.6, 0.6)
	item_tab.add_theme_color_override("font_color", active if current_view == View.ITEMS else inactive)
	equipment_tab.add_theme_color_override("font_color", active if current_view == View.EQUIPMENT else inactive)

func _refresh_current_view():
	if not inventory:
		return
	match current_view:
		View.ITEMS:
			_refresh_items()
		View.EQUIPMENT:
			_refresh_equipment()
		View.DETAIL:
			_refresh_detail()

# --- Cell helpers ---

func _clear_cell(cell):
	cell.get_node("Icon").texture = null
	cell.get_node("Icon").modulate = Color.WHITE
	cell.get_node("Count").text = ""
	cell.add_theme_stylebox_override("panel", normal_style)

func _fill_cell(cell, texture: Texture2D, count_text: String = "", tint: Color = Color.WHITE):
	cell.get_node("Icon").texture = texture
	cell.get_node("Icon").modulate = tint
	cell.get_node("Count").text = count_text

# --- Items view ---

func _refresh_items():
	item_cell_ids.clear()
	for cell in item_cells:
		_clear_cell(cell)

	var items = inventory.get_items()
	var ids = items.keys()
	# Keep selection valid.
	if item_selected_id != "" and not items.has(item_selected_id):
		item_selected_id = ""
	if item_selected_id == "" and not ids.is_empty():
		item_selected_id = ids[0]

	var i = 0
	for item_id in ids:
		if i >= item_cells.size():
			break
		var cell = item_cells[i]
		_fill_cell(cell, inventory.get_item_icon(item_id), str(items[item_id]), inventory.get_item_color(item_id))
		item_cell_ids[cell] = item_id
		if item_id == item_selected_id:
			cell.add_theme_stylebox_override("panel", selected_style)
		i += 1

	_update_item_actions()

func _update_item_actions():
	if item_selected_id == "" or not inventory.has_item(item_selected_id):
		description_label.text = ""
		use_button.visible = false
		discard_button.visible = false
		return

	description_label.text = "%s\n%s" % [
		inventory.get_item_name(item_selected_id),
		inventory.get_item_description(item_selected_id)
	]
	# The Use button only appears for usable items.
	use_button.visible = inventory.is_item_usable(item_selected_id)
	use_button.disabled = not inventory.can_use_item(item_selected_id)
	discard_button.visible = true

func _on_item_cell_input(event: InputEvent, cell):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if item_cell_ids.has(cell):
			item_selected_id = item_cell_ids[cell]
			_refresh_items()

func _on_use_pressed():
	if item_selected_id != "" and inventory.can_use_item(item_selected_id):
		inventory.use_item(item_selected_id)

func _on_discard_pressed():
	if item_selected_id != "":
		inventory.discard_item(item_selected_id)

# --- Equipment view ---

func _refresh_equipment():
	# Weapon boxes
	_fill_equip_box("melee", inventory.get_equipped_melee_id(), true)
	_fill_equip_box("range", inventory.get_equipped_ranged_id(), true)
	# Armor boxes
	for slot in ARMOR_SLOTS:
		_fill_equip_box(slot, inventory.equipped_armor.get(slot, ""), false)

	# Stats panel
	var hp_text = "?"
	if player:
		hp_text = "%d / %d" % [player.current_hp, player.max_hp]
	stats_label.text = "HP: %s\nAttack: %d\nArmor: %d" % [
		hp_text, inventory.get_total_attack(), inventory.get_total_armor()
	]

func _fill_equip_box(slot: String, equipped_id: String, is_weapon: bool):
	var cell = equip_cells[slot]
	_clear_cell(cell)
	if equipped_id == "":
		return
	if is_weapon:
		_fill_cell(cell, inventory.get_weapon_icon(equipped_id))
	else:
		_fill_cell(cell, inventory.get_armor_icon(equipped_id))
	cell.add_theme_stylebox_override("panel", equipped_style)

func _on_equip_box_input(event: InputEvent, slot: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		detail_slot = slot
		detail_selected_id = ""
		_show_view(View.DETAIL)

# --- Detail view ---

# Candidates for the current detail slot: weapons by type, or armor by slot.
func _detail_candidates() -> Dictionary:
	if detail_slot == "melee":
		return inventory.get_weapons_by_type("melee")
	elif detail_slot == "range":
		return inventory.get_weapons_by_type("ranged")
	else:
		return inventory.get_armors_by_slot(detail_slot)

func _slot_is_weapon() -> bool:
	return detail_slot == "melee" or detail_slot == "range"

func _refresh_detail():
	detail_title.text = detail_slot

	detail_cell_ids.clear()
	for cell in detail_cells:
		_clear_cell(cell)

	var candidates = _detail_candidates()
	var ids = candidates.keys()

	# Default the selection to the equipped piece, else the first candidate.
	if detail_selected_id != "" and not candidates.has(detail_selected_id):
		detail_selected_id = ""
	if detail_selected_id == "":
		for id in ids:
			if _is_equipped(id):
				detail_selected_id = id
				break
	if detail_selected_id == "" and not ids.is_empty():
		detail_selected_id = ids[0]

	var i = 0
	for id in ids:
		if i >= detail_cells.size():
			break
		var cell = detail_cells[i]
		var marker = ""
		if _slot_is_weapon() and inventory.is_weapon_ranged(id):
			marker = "x%d" % inventory.get_weapon_count(id)
		_fill_cell(cell, _candidate_icon(id), marker)
		detail_cell_ids[cell] = id
		if id == detail_selected_id:
			cell.add_theme_stylebox_override("panel", selected_style)
		elif _is_equipped(id):
			cell.add_theme_stylebox_override("panel", equipped_style)
		i += 1

	_update_detail_actions()

func _candidate_icon(id: String) -> Texture2D:
	if _slot_is_weapon():
		return inventory.get_weapon_icon(id)
	return inventory.get_armor_icon(id)

func _is_equipped(id: String) -> bool:
	if _slot_is_weapon():
		return inventory.is_weapon_equipped(id)
	return inventory.is_armor_equipped(id)

func _update_detail_actions():
	if detail_selected_id == "":
		detail_description.text = "Nothing here yet."
		equip_button.visible = false
		return

	equip_button.visible = true
	var id = detail_selected_id
	if _slot_is_weapon():
		var w = inventory.weapons[id]
		if inventory.is_weapon_ranged(id):
			detail_description.text = "%s\n%s\nDMG %s  ·  x%s left" % [
				inventory.get_weapon_name(id), inventory.get_weapon_description(id),
				str(w.get("damage", 1)), str(inventory.get_weapon_count(id))
			]
		else:
			detail_description.text = "%s\n%s\nDMG %s  ·  SPD %s" % [
				inventory.get_weapon_name(id), inventory.get_weapon_description(id),
				str(w.get("damage", 1)), str(w.get("attack_speed", 1.0))
			]
	else:
		detail_description.text = "%s\n%s\nArmor +%d" % [
			inventory.get_armor_name(id), inventory.get_armor_description(id),
			inventory.get_armor_value(id)
		]
	equip_button.text = "Unequip" if _is_equipped(id) else "Equip"

func _on_detail_cell_input(event: InputEvent, cell):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if detail_cell_ids.has(cell):
			detail_selected_id = detail_cell_ids[cell]
			_refresh_detail()

func _on_equip_pressed():
	if detail_selected_id == "":
		return
	if _slot_is_weapon():
		inventory.toggle_equip_weapon(detail_selected_id)
	else:
		inventory.toggle_equip_armor(detail_selected_id)
	_refresh_detail()

# --- Input ---

func _input(event):
	if not visible:
		# Don't open while something else paused the tree (e.g. pause menu).
		if event.is_action_pressed("open_inventory") and not get_tree().paused:
			toggle_visibility()
		return

	# ESC always closes the whole backpack; the inventory key toggles it too.
	if event.is_action_pressed("open_inventory") or event.is_action_pressed("ui_cancel"):
		toggle_visibility()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		# E activates the current selection: use an item, or equip/unequip.
		if current_view == View.ITEMS:
			_on_use_pressed()
		elif current_view == View.DETAIL:
			_on_equip_pressed()
		get_viewport().set_input_as_handled()
