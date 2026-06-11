extends Control

# Bar dimensions (match hp_hud.tscn). The red fill spans the area inside
# the black border; the gray panel behind it shows health already lost.
const BAR_WIDTH := 200.0
const BORDER := 3.0

@onready var health_fill = $HealthBar/HealthFill

func update_health(current_hp):
	# Get max HP from player
	var max_hp = get_node("/root/Level/Player").max_hp

	# Fraction of health remaining (red portion)
	var ratio = 0.0
	if max_hp > 0:
		ratio = clamp(float(current_hp) / float(max_hp), 0.0, 1.0)

	# Resize the red fill inside the border; the rest stays gray
	var inner_width = BAR_WIDTH - BORDER * 2
	health_fill.offset_right = BORDER + inner_width * ratio
