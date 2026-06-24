extends Control

# Called when the node enters the scene tree for the first time
func _ready():
	# Set this node to process input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect button signals
	$VBoxContainer/ResumeButton.pressed.connect(_on_resume_button_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_button_pressed)

func _input(event):
	# Allow ESC to resume the game while the pause menu is showing.
	# Consuming the event keeps the level from re-detecting ESC and re-pausing.
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_parent().get_parent().toggle_pause()

func _on_resume_button_pressed():
	# Notify level to unpause
	get_parent().get_parent().toggle_pause()

func _on_quit_button_pressed():
	# Quit the game
	get_tree().change_scene_to_file("res://scenes/ui/menu.tscn")
