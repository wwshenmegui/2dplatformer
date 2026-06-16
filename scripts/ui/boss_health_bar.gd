extends Control

## Health bar for a boss (the dragon). Hidden by default; level.gd calls setup()
## when a boss is present in the level, then the boss's health_changed signal
## drives update_health(). The red fill spans the area inside the black border.
const BAR_WIDTH := 400.0
const BORDER := 3.0

@onready var health_fill: ColorRect = $HealthBar/HealthFill
@onready var name_label: Label = $NameLabel

var _max_health: int = 1

# Show the bar and set its label / starting fill.
func setup(boss_name: String, max_health: int) -> void:
	_max_health = max(max_health, 1)
	name_label.text = boss_name
	visible = true
	update_health(max_health)

func update_health(current: int) -> void:
	var ratio := clampf(float(current) / float(_max_health), 0.0, 1.0)
	var inner_width := BAR_WIDTH - BORDER * 2
	health_fill.offset_right = BORDER + inner_width * ratio
