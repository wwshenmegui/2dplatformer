extends CharacterBody2D
class_name Dragon

## Boss enemy. Chases the player and picks an attack based on range:
##   * within claw_range  -> melee CLAW attack
##   * within fire_range  -> ranged FIRE attack (spits a fireball)
## On top of that it jumps at random intervals. Lives in the "Enemies" group so
## the player's weapon can damage it and level.gd can react to damage_player.

signal damage_player
signal boss_died
signal health_changed(current: int, max: int)

enum State { CHASE, CLAW, FIRE, DEAD }

# --- Movement ---
@export var speed: float = 130.0
@export var gravity: float = 30.0
@export var jump_force: float = 650.0

# --- Combat ---
@export var max_health: int = 12
@export var contact_damage: int = 1
@export var claw_damage: int = 2

# Horizontal distance to the player that triggers each attack. Inside claw_range
# it claws; between claw_range and fire_range it breathes fire.
@export var claw_range: float = 130.0
@export var fire_range: float = 650.0
@export var claw_cooldown: float = 1.2
@export var fire_cooldown: float = 2.5

# Random jump cadence: the next jump fires after a random delay in this window.
@export var jump_interval_min: float = 2.0
@export var jump_interval_max: float = 5.0

@export var fireball_scene: PackedScene

var current_health: int = max_health
var state: State = State.CHASE
var facing: int = -1                       # -1 = facing left (sheet default), 1 = right

var claw_timer: float = 0.0
var fire_timer: float = 0.0
var jump_timer: float = 0.0

var player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var claw_hitbox: Area2D = $ClawHitbox
@onready var claw_shape: CollisionShape2D = $ClawHitbox/CollisionShape2D
@onready var contact_box: Area2D = $ContactBox
@onready var fire_point: Marker2D = $FirePoint
@onready var edge_check: RayCast2D = $EdgeCheck

func _ready() -> void:
	add_to_group("Enemies")
	current_health = max_health
	_enable_claw(false)
	claw_hitbox.body_entered.connect(_on_claw_hit)
	contact_box.body_entered.connect(_on_contact)
	_reset_jump_timer()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	# Gravity (per-frame impulse, matching the rest of this project's actors).
	if not is_on_floor():
		velocity.y += gravity

	claw_timer = maxf(0.0, claw_timer - delta)
	fire_timer = maxf(0.0, fire_timer - delta)
	jump_timer -= delta

	_acquire_player()

	# While committed to an attack the AI is locked: bleed off horizontal speed
	# and let the animation play out (it returns the dragon to CHASE when done).
	if state == State.CLAW or state == State.FIRE:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		move_and_slide()
		return

	_think()
	move_and_slide()

	# Animation is driven by physics while free to move (attacks set their own).
	if state == State.CHASE:
		_update_animation()

# Decide what to do this frame: jump, attack, chase, or wait.
func _think() -> void:
	if player == null:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = absf(to_player.x)
	_face(signf(to_player.x))

	# Random jump — only ever launches from the ground.
	if jump_timer <= 0.0 and is_on_floor():
		_do_jump()
		return

	# Attack decisions are made from the ground.
	if is_on_floor():
		if dist <= claw_range and claw_timer <= 0.0:
			_start_claw()
			return
		elif dist <= fire_range and fire_timer <= 0.0:
			_start_fire()
			return

	# Otherwise close the distance, but never walk off a ledge or into a wall.
	if dist > claw_range * 0.7 and _can_advance():
		velocity.x = facing * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)

# --- Jump ---------------------------------------------------------------------

func _do_jump() -> void:
	velocity.y = -jump_force
	velocity.x = facing * speed
	_reset_jump_timer()

func _reset_jump_timer() -> void:
	jump_timer = randf_range(jump_interval_min, jump_interval_max)

# --- Claw (melee) -------------------------------------------------------------

func _start_claw() -> void:
	state = State.CLAW
	claw_timer = claw_cooldown
	velocity.x = 0.0
	_play("claw")
	_swing_claw()
	await anim.animation_finished
	if state == State.CLAW:
		state = State.CHASE

# Open the claw's damage window for the middle of the swing only.
func _swing_claw() -> void:
	await get_tree().create_timer(0.25).timeout
	if state != State.CLAW:
		return
	_enable_claw(true)
	await get_tree().create_timer(0.35).timeout
	_enable_claw(false)

func _enable_claw(on: bool) -> void:
	claw_hitbox.monitoring = on
	claw_shape.set_deferred("disabled", not on)

# --- Fire (ranged) ------------------------------------------------------------

func _start_fire() -> void:
	state = State.FIRE
	fire_timer = fire_cooldown
	velocity.x = 0.0
	_play("fire")
	_spawn_fireball_when_ready()
	await anim.animation_finished
	if state == State.FIRE:
		state = State.CHASE

# Spawn the fireball partway through the animation, as the mouth-flame appears.
func _spawn_fireball_when_ready() -> void:
	await get_tree().create_timer(0.5).timeout
	if state != State.FIRE:
		return
	breathe_fire()

func breathe_fire() -> void:
	if fireball_scene == null or player == null:
		return
	var fb: Node = fireball_scene.instantiate()
	get_parent().add_child(fb)
	fb.global_position = fire_point.global_position
	fb.direction = (player.global_position - fire_point.global_position).normalized()

# --- Helpers ------------------------------------------------------------------

func _acquire_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")

func _face(dir: float) -> void:
	if dir == 0.0:
		return
	facing = int(signf(dir))
	# Sheet faces right by default; flip to face left.
	sprite.flip_h = facing < 0
	# Mirror the offsets of the mouth and claw to the facing side.
	fire_point.position.x = absf(fire_point.position.x) * facing
	claw_hitbox.position.x = absf(claw_hitbox.position.x) * facing

# Is there ground ahead (and no wall) so the dragon can keep advancing?
func _can_advance() -> bool:
	if is_on_wall():
		return false
	if not is_on_floor():
		return true
	edge_check.position.x = absf(edge_check.position.x) * facing
	edge_check.force_raycast_update()
	return edge_check.is_colliding()

func _play(name: String) -> void:
	if anim.current_animation != name:
		anim.play(name)

func _update_animation() -> void:
	if not is_on_floor():
		_play("jump")
	elif absf(velocity.x) > 10.0:
		_play("move")
	else:
		_play("idle")

# --- Damage -------------------------------------------------------------------

# Hit by the player's weapon. Bosses ignore knockback/slow, so only take_damage
# is implemented (apply_attack_slowdown is intentionally absent).
func take_damage(amount: int = 1) -> void:
	if state == State.DEAD:
		return
	current_health -= amount
	health_changed.emit(current_health, max_health)
	modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(0.12).timeout
	if state != State.DEAD:
		modulate = Color(1, 1, 1)
	if current_health <= 0:
		die()

func _on_contact(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("take_damage") and not body.is_invincible:
		body.take_damage(contact_damage, global_position)
		damage_player.emit()

func _on_claw_hit(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("take_damage") and not body.is_invincible:
		body.take_damage(claw_damage, global_position)
		damage_player.emit()

func die() -> void:
	state = State.DEAD
	boss_died.emit()
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	contact_box.set_deferred("monitoring", false)
	_enable_claw(false)
	_play("idle")
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
	await tween.finished
	queue_free()
