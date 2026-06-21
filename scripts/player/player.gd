extends CharacterBody2D

class_name Player

signal player_died
signal coins_changed(amount)

# movement variables
@export var speed = 500
@export var gravity = 30
@export var jumpforce = 700

# Double jump (air jump) ability — toggle on/off
@export var double_jump_enabled = false
var jumps_made = 0

# Dash ability — toggle on/off
@export var dash_enabled = false
@export var dash_speed = 1200
@export var dash_duration = 0.2
@export var dash_cooldown = 0.5
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = 1
# Set true after an air dash; blocks further dashing until the player lands
var air_dash_used = false

# Wall jump / wall cling ability — toggle on/off
@export var wall_jump_enabled = false
# Max downward speed while clinging to a wall (slow slide, like Hollow Knight)
@export var wall_slide_speed = 80
# Launch impulse on a wall jump: x pushes away from the wall, y throws upward
@export var wall_jump_force = Vector2(600, 650)
# How long horizontal input is suspended after a wall jump so the push-away
# from the wall isn't immediately cancelled by movement input
@export var wall_jump_lock_duration = 0.18
var is_wall_clinging = false
var wall_jump_lock_timer = 0.0

@export var max_hp = 20
var current_hp = max_hp
var is_dead = false

# invincibility properties
var is_invincible = false
var invincibility_duration = 1.5  # Duration in seconds
var invincibility_timer = 0.0
var flash_timer = 0.0

# Knockback variables
var knockback_force = Vector2(300, -200)  # Horizontal and vertical force
var is_being_knocked_back = false
var knockback_direction = Vector2.ZERO

# Inventory system
var inventory = Inventory.new()

# Coin system
var coins = 0

@onready var animated_sprite = $AnimatedSprite2D

# Sound effects
@onready var coin_sound = $CoinSound
@onready var hurt_sound = $HurtSound
@onready var jump_sound = $JumpSound

# Attack
@export var can_attack = true
@export var attack_cooldown = 0.5
# Multiplier on the attack area's size (1.0 = original)
@export var attack_size = 1.5
var is_attack_on_cooldown = false

@onready var attack_area = $PlayerAttack
# Base combat stats (no weapon equipped), captured in _ready so an equipped
# weapon can override them and unequipping can restore them.
var base_attack_cooldown = 0.0
var base_attack_damage = 0
# Movement slowdown of the currently equipped weapon (0 when unarmed).
var equipped_slowdown = 0.0
# Authored offset of the attack area (facing right). Mirrored when facing left.
var attack_base_position_x = 0.0
# Authored horizontal/vertical scale of the attack area, before the size
# multiplier. The horizontal magnitude is mirrored by facing.
var attack_base_scale_x = 0.0
var attack_base_scale_y = 0.0

# Ranged (throwable) weapon state. When a ranged weapon such as a bomb is
# equipped, the attack input throws a projectile instead of swinging the melee
# attack area. equipped_throw_scene is null when the equipped weapon is melee.
var equipped_throw_scene: PackedScene = null
var equipped_throw_element = 0
var equipped_throw_damage = 0
# Launch velocity for a thrown weapon (x is mirrored by facing).
@export var throw_speed = 700.0
@export var throw_upward = 250.0

func _ready() -> void:
	add_to_group("Player")

	# Remember the attack's resting offset so we can mirror it by facing,
	# and its authored vertical scale so we can apply the size multiplier.
	attack_base_position_x = attack_area.position.x
	attack_base_scale_x = abs(attack_area.scale.x)
	attack_base_scale_y = attack_area.scale.y

	# Remember the unarmed combat stats so weapons can modify and restore them.
	base_attack_cooldown = attack_cooldown
	base_attack_damage = attack_area.damage

	# Set this player as the inventory owner
	inventory.set_owner(self)

	# Connect to inventory item_used signal
	inventory.item_used.connect(_on_item_used)

	# Re-apply combat stats whenever the equipped weapons change.
	inventory.weapons_changed.connect(_apply_equipped_weapons)

	# Restore carried-over progress from a previous level, or start fresh.
	if GameState.has_state:
		GameState.load_into_player(self)
		coins_changed.emit(coins)
		inventory.inventory_changed.emit()
		inventory.weapons_changed.emit()
		inventory.armor_changed.emit()
		# Re-apply the equipped weapons' stats after a level transition.
		_apply_equipped_weapons()
	else:
		current_hp = max_hp
		# Seed a starter set of armor so the equipment UI is populated.
		for armor_id in inventory.armor_properties.keys():
			inventory.add_armor(armor_id, inventory.armor_properties[armor_id].duplicate(true))

	# Notify the HUD to update
	update_hp_display()


func _physics_process(delta: float) -> void:
	# Tick down the dash cooldown
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	# While dashing, movement is fully controlled by the dash
	if is_dashing:
		_process_dash(delta)
		move_and_slide()
		update_animation(dash_direction)
		return

	# Add the gravity
	if not is_on_floor():
		velocity.y += gravity
		if velocity.y > 500:
			velocity.y = 500
	else:
		# Landed — refill the air-jump allowance and re-arm the air dash
		jumps_made = 0
		air_dash_used = false
	
	var horizontal_direction = 0
	if not is_being_knocked_back:
		horizontal_direction = Input.get_axis("move_left", "move_right")

		# Wall cling: while airborne and pressing into a wall, grab on.
		_update_wall_cling(horizontal_direction)

		if Input.is_action_just_pressed("jump"):
			if is_wall_clinging:
				_wall_jump()
				jump_sound.play()
			elif _can_jump():
				velocity.y = -jumpforce
				jumps_made += 1
				jump_sound.play()

		# Horizontal control is suspended briefly after a wall jump so the
		# push-away from the wall isn't immediately cancelled by input.
		if wall_jump_lock_timer > 0.0:
			wall_jump_lock_timer -= delta
		else:
			velocity.x = speed * horizontal_direction

		# While clinging, cap the descent to a slow slide.
		if is_wall_clinging and velocity.y > wall_slide_speed:
			velocity.y = wall_slide_speed

		# Swinging a weapon slows the player down (by the weapon's slowdown).
		if attack_area.is_attacking:
			velocity.x *= _attack_move_factor()

		# Start a dash if enabled, off cooldown, and not already air-dashed
		if dash_enabled and Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not air_dash_used:
			_start_dash(horizontal_direction)
		
	move_and_slide()

	update_animation(horizontal_direction)
		
	# Check if knockback should end
	if is_being_knocked_back and is_on_floor() and velocity.y >= 0:
		is_being_knocked_back = false
		
	# Handle attack input. Melee (J) swings the attack area; ranged (K) throws a
	# projectile. The two are independent — both can be equipped at once.
	if can_attack and not is_attack_on_cooldown:
		if Input.is_action_just_pressed("attack") and _has_melee_equipped():
			attack()
		elif Input.is_action_just_pressed("attack_ranged") and _has_ranged_equipped():
			throw_bomb()

# Can the player jump right now? Always true on the floor; in the air only
# when double jump is enabled and an air jump is still available.
func _can_jump() -> bool:
	if is_on_floor():
		return true
	var max_jumps = 2 if double_jump_enabled else 1
	return jumps_made < max_jumps

# Decide whether the player is currently clinging to a wall: the ability must
# be enabled, the player airborne and not dashing, touching a wall, and pressing
# into it. Grabbing the wall refreshes the air-jump and air-dash allowances.
func _update_wall_cling(horizontal_direction: float) -> void:
	if not wall_jump_enabled or is_dashing or is_on_floor() or not is_on_wall():
		is_wall_clinging = false
		return

	# get_wall_normal() points from the wall toward the player, so pressing into
	# the wall means input goes opposite to the normal's horizontal direction.
	var wall_normal = get_wall_normal()
	var pushing_into_wall = horizontal_direction != 0 and signf(horizontal_direction) == -signf(wall_normal.x)

	var was_clinging = is_wall_clinging
	is_wall_clinging = pushing_into_wall

	# First frame of a fresh grab re-arms air abilities, like landing.
	if is_wall_clinging and not was_clinging:
		jumps_made = 0
		air_dash_used = false

# Launch off the wall: thrown upward and pushed away from the wall surface.
func _wall_jump() -> void:
	var wall_normal = get_wall_normal()
	velocity.y = -wall_jump_force.y
	velocity.x = wall_normal.x * wall_jump_force.x
	is_wall_clinging = false
	wall_jump_lock_timer = wall_jump_lock_duration
	# Face away from the wall we just kicked off.
	animated_sprite.flip_h = wall_normal.x < 0
	# A wall jump doesn't consume an air jump.
	jumps_made = 0

# Begin a dash in the input direction, or the facing direction if no input.
func _start_dash(input_direction: float) -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	# An air dash can't be repeated until the player touches the ground again
	if not is_on_floor():
		air_dash_used = true
	if input_direction != 0:
		dash_direction = signf(input_direction)
	else:
		dash_direction = -1 if animated_sprite.flip_h else 1
	animated_sprite.flip_h = dash_direction < 0

# Drive a horizontal dash, ignoring gravity for its short duration.
func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity.x = dash_direction * dash_speed
	velocity.y = 0
	if dash_timer <= 0.0:
		is_dashing = false
	
func update_animation(direction):
	if direction != 0:
		animated_sprite.flip_h = (direction == -1)

	# Let the one-shot attack animation play out without being overridden.
	if animated_sprite.animation == "attack" and animated_sprite.is_playing():
		return

	if not is_on_floor():
		animated_sprite.play("jump")
	elif is_invincible:
		# play invincible (hurt flash) animation
		animated_sprite.play("take_damage")
	elif direction == 0:
		animated_sprite.play("idle")
	else:
		animated_sprite.play("run")
			
func update_hp_display():
	# Signal to update the HUD
	var hud = get_node("/root/Level/UILayer/HpHud")
	if hud:
		hud.update_health(current_hp)

	
func take_damage(amount: int = 1, knockback_source_position = null) -> void:
	if is_dead:
		return

	# Equipped armor mitigates incoming damage, but a hit always deals at least 1.
	if amount > 0:
		amount = max(amount - inventory.get_total_armor(), 1)

	current_hp -= amount
	update_hp_display()
	hurt_sound.play()

	# Apply knockback if a source position is provided
	if knockback_source_position != null:
		apply_knockback(knockback_source_position)
	
	if current_hp <= 0:
		die()
	else:
		start_invincibility()
		
func apply_knockback(source_position):
	# Calculate direction away from the source (only for horizontal direction)
	var dir_to_player = global_position - source_position
	knockback_direction.x = 1 if dir_to_player.x > 0 else -1
	
	# Apply the knockback as an impulse
	velocity.x = knockback_direction.x * knockback_force.x
	velocity.y = knockback_force.y  # Always jump up a bit
	
	is_being_knocked_back = true
		
func start_invincibility():
	is_invincible = true
	invincibility_timer = invincibility_duration
	await get_tree().create_timer(invincibility_timer).timeout
	end_invincibility()
	
func end_invincibility():
	is_invincible = false
	
func can_heal() -> bool:
	return !is_dead and current_hp < max_hp
	
func heal(amount: int = 1) -> void:
	if not can_heal():
		return
		
	current_hp = min(current_hp + amount, max_hp)
	update_hp_display()

func die() -> void:
	is_dead = true
	# You might want to play death animation here
	# Disable player controls
	set_physics_process(false)
	animated_sprite.play("die")
	await get_tree().create_timer(1.0).timeout
	# Notify level about player death
	player_died.emit()
	
# Item collection
func collect_item(item_id: String) -> void:
	inventory.add_item(item_id)
	coin_sound.play()
	print("Collected item: ", item_id)

# Weapon pickup — store it in the inventory's weapon section. If the matching
# category slot (melee/ranged) is empty, equip the new weapon automatically.
func collect_weapon(weapon_id: String, props: Dictionary) -> void:
	inventory.add_weapon(weapon_id, props)
	print("Picked up weapon: ", weapon_id)

	if inventory.is_weapon_ranged(weapon_id):
		if inventory.equipped_ranged_id == "":
			inventory.toggle_equip_weapon(weapon_id)
	elif inventory.equipped_melee_id == "":
		inventory.toggle_equip_weapon(weapon_id)

# Armor pickup — store it and auto-equip if its body slot is empty.
func collect_armor(armor_id: String, props: Dictionary) -> void:
	inventory.add_armor(armor_id, props)
	print("Picked up armor: ", armor_id)

	var slot = props.get("slot", "")
	if inventory.equipped_armor.get(slot, "") == "":
		inventory.toggle_equip_armor(armor_id)

# Apply both equipped weapon slots: melee stats for the attack swing, and the
# throw state for the ranged weapon. Either may be empty (restores defaults).
func _apply_equipped_weapons() -> void:
	_apply_melee()
	_apply_ranged()

# Configure the melee swing from the equipped melee weapon, or restore unarmed.
func _apply_melee() -> void:
	var melee_id = inventory.equipped_melee_id
	if melee_id == "" or not inventory.weapons.has(melee_id):
		attack_cooldown = base_attack_cooldown
		attack_area.damage = base_attack_damage
		equipped_slowdown = 0.0
		attack_area.set_weapon(null, 1.0, 0.0)
		return

	var props = inventory.weapons[melee_id]
	attack_area.damage = props.get("damage", base_attack_damage)
	# Higher attack_speed means a shorter cooldown between swings.
	var speed_mult = props.get("attack_speed", 1.0)
	attack_cooldown = base_attack_cooldown / max(speed_mult, 0.01)
	equipped_slowdown = props.get("slowdown", 0.0)
	# Show the equipped weapon's texture (scaled to its length) on the swing.
	attack_area.set_weapon(
		props.get("icon_texture", null),
		props.get("attack_scale", 1.0),
		equipped_slowdown
	)

# Arm (or disarm) the thrown projectile from the equipped ranged weapon.
func _apply_ranged() -> void:
	var ranged_id = inventory.equipped_ranged_id
	if ranged_id == "" or not inventory.weapons.has(ranged_id):
		equipped_throw_scene = null
		return

	var props = inventory.weapons[ranged_id]
	equipped_throw_scene = props.get("throw_scene", null)
	equipped_throw_element = props.get("element", 0)
	equipped_throw_damage = props.get("damage", base_attack_damage)

# Throw the equipped bomb: spawn its projectile in the facing direction and
# spend one unit of ammo. Using the last bomb unequips it (handled by the
# inventory), which clears the ranged state via _apply_equipped_weapons.
func throw_bomb() -> void:
	if is_dead or equipped_throw_scene == null:
		return

	var weapon_id = inventory.equipped_ranged_id
	if inventory.get_weapon_count(weapon_id) <= 0:
		return

	var facing = -1 if animated_sprite.flip_h else 1
	var bomb = equipped_throw_scene.instantiate()
	bomb.element = equipped_throw_element
	bomb.damage = equipped_throw_damage
	bomb.global_position = global_position + Vector2(facing * 30, -20)
	bomb.velocity = Vector2(facing * throw_speed, -throw_upward)
	get_parent().add_child(bomb)

	inventory.consume_weapon_ammo(weapon_id)

	# Reuse the attack cooldown to pace throws.
	is_attack_on_cooldown = true
	await get_tree().create_timer(attack_cooldown).timeout
	is_attack_on_cooldown = false

# How much the player's movement speed is scaled while mid-swing. The weapon's
# slowdown magnitude reduces speed (down to a floor so the player never freezes).
func _attack_move_factor() -> float:
	return clampf(1.0 - abs(equipped_slowdown), 0.15, 1.0)
	
# Coin collection
func collect_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	print("Collected ", amount, " coins. Total: ", coins)
	
	# Optional: Show a floating "+1" text or play a sound
	# show_coin_collected_effect(amount)
	
# The player can only swing while a melee weapon is equipped, and only throw
# while a ranged weapon is equipped.
func _has_melee_equipped() -> bool:
	return inventory.equipped_melee_id != ""

func _has_ranged_equipped() -> bool:
	return inventory.equipped_ranged_id != ""

func attack() -> void:
	if is_dead or not _has_melee_equipped():
		return
		
	# Play the attack animation, restarting from the first frame so each swing
	# shows the full motion even if the previous one hadn't finished.
	animated_sprite.play("attack")
	animated_sprite.frame = 0

	# Set direction of attack area based on player facing direction.
	# Mirror both the horizontal scale AND the offset so that, facing left,
	# the attack is the mirror image of facing right (blade in front).
	var facing_direction = 1 if not animated_sprite.flip_h else -1
	attack_area.scale.x = facing_direction * attack_base_scale_x * attack_size
	attack_area.scale.y = attack_base_scale_y * attack_size
	attack_area.position.x = attack_base_position_x * facing_direction

	# Trigger the attack effect
	attack_area.attack()
	
	# Start cooldown
	is_attack_on_cooldown = true
	await get_tree().create_timer(attack_cooldown).timeout
	is_attack_on_cooldown = false
	
# Handle item usage
func _on_item_used(item_id: String) -> void:
	var effect_data = inventory.get_item_effect(item_id)
	
	match effect_data.effect:
		"heal":
			heal(effect_data.value)
			print("Used healing item: +" + str(effect_data.value) + " HP")
		_:
			print("Used item: " + item_id)
