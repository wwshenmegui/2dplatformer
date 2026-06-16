extends Control

# Level scenes in play order, indexed by the level-select buttons.
const LEVEL_SCENES := [
	"res://scenes/levels/level.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
]

@onready var main_menu = $VBoxContainer
@onready var start_button = $VBoxContainer/StartButton
@onready var select_level_button = $VBoxContainer/SelectLevelButton
@onready var exit_button = $VBoxContainer/ExitButton

@onready var level_select = $LevelSelectContainer
@onready var level1_button = $LevelSelectContainer/Level1Button
@onready var level2_button = $LevelSelectContainer/Level2Button
@onready var level3_button = $LevelSelectContainer/Level3Button
@onready var back_button = $LevelSelectContainer/BackButton

func _ready():
	get_tree().paused = false
	# Set focus to start button when scene loads
	start_button.grab_focus()

	# Connect button signals to their respective functions
	start_button.pressed.connect(_on_start_button_pressed)
	select_level_button.pressed.connect(_on_select_level_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

	# Level select buttons each launch a fresh playthrough at their level.
	level1_button.pressed.connect(_on_level_button_pressed.bind(0))
	level2_button.pressed.connect(_on_level_button_pressed.bind(1))
	level3_button.pressed.connect(_on_level_button_pressed.bind(2))
	back_button.pressed.connect(_on_back_button_pressed)

func _on_start_button_pressed():
	_start_level(0)

func _on_select_level_button_pressed():
	# Swap the main menu for the level-select panel.
	main_menu.visible = false
	level_select.visible = true
	level1_button.grab_focus()

func _on_back_button_pressed():
	level_select.visible = false
	main_menu.visible = true
	start_button.grab_focus()

func _on_level_button_pressed(level_index: int):
	_start_level(level_index)

func _on_exit_button_pressed():
	# Quit the game
	get_tree().quit()

# Start a brand-new playthrough with no carried-over progress at the given level.
func _start_level(level_index: int):
	GameState.reset()
	get_tree().change_scene_to_file(LEVEL_SCENES[level_index])
