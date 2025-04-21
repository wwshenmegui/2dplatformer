extends Control

@onready var health_label = $HealthLabel

func _ready():
	# Initialize the label
	pass

func update_health(current_hp):
	# Get max HP from player
	var max_hp = get_node("/root/Level/Player").max_hp
	
	# Update the label text
	health_label.text = "HP: " + str(current_hp) + "/" + str(max_hp)
