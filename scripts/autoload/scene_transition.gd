extends CanvasLayer

# A full-screen fade-to-black used when moving between levels. Registered as the
# "SceneTransition" autoload so the overlay persists across change_scene_to_file()
# and can fade out the old scene, swap, then fade in the new one.

# Half of the total transition; out + in is roughly a one second blackout.
const FADE_TIME := 0.5

var _rect: ColorRect

func _ready() -> void:
	# Draw above every in-level CanvasLayer (UILayer, HUD, pause menu, ...).
	layer = 128
	# Animate even while the tree is paused during the fade-out.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)  # start fully transparent so the menu shows
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never swallow input
	add_child(_rect)

# Fade to black, swap to the given scene, then fade back in. Safe to call
# without awaiting — gameplay is frozen while the screen goes dark.
func change_scene(path: String) -> void:
	get_tree().paused = true
	await _fade_to(1.0)

	get_tree().change_scene_to_file(path)
	# Let the new scene instance and run _ready before revealing it.
	await get_tree().process_frame
	get_tree().paused = false

	await _fade_to(0.0)

func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", alpha, FADE_TIME)
	await tween.finished
