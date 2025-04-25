extends Control

@onready var start_button = $VBoxContainer/StartButton
@onready var exit_button = $VBoxContainer/ExitButton

func _ready():
	get_tree().paused = false
	# Set focus to start button when scene loads
	start_button.grab_focus()
	
	# Connect button signals to their respective functions
	start_button.pressed.connect(_on_start_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

func _on_start_button_pressed():
	# Change to your first game level scene
	get_tree().change_scene_to_file("res://scenes/levels/level.tscn")
	
func _on_exit_button_pressed():
	# Quit the game
	get_tree().quit()
