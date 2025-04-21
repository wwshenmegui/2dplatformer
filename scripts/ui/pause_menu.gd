extends Control

# Called when the node enters the scene tree for the first time
func _ready():
	# Set this node to process input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect button signals
	$VBoxContainer/ResumeButton.pressed.connect(_on_resume_button_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_button_pressed)

func _on_resume_button_pressed():
	# Notify level to unpause
	get_parent().get_parent().toggle_pause()

func _on_quit_button_pressed():
	# Quit the game
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
