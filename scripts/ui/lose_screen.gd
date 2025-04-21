extends Control

@onready var restart_button = $RestartButton
@onready var exit_button = $ExitButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Set focus to start button when scene loads
	restart_button.grab_focus()
	
	# Connect button signals to their respective functions
	restart_button.pressed.connect(_on_restart_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

func _on_restart_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/level.tscn")
	
func _on_exit_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
