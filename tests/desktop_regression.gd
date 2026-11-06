extends SceneTree
## Run: Godot --headless --path . --script res://tests/desktop_regression.gd

var passed := 0
var failed := 0
var interaction: Node
var player: Node3D
var panel: Node3D
var surface: SubViewport

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(20.0).timeout.connect(func():
		push_error("Desktop suite timed out")
		quit(1)
	)
	# A runtime error in a test must not silently turn into a successful suite.
	for test_name in ["test_desktop_session", "test_text_entry_and_cancel", "test_mouse_release", "test_removed_panel", "test_no_hardware"]:
		if await call(test_name) != true:
			check(false, test_name + " did not finish")
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(panel):
		panel.queue_free()
	await process_frame
	print("Desktop regression: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event

func test_desktop_session() -> bool:
	if not ResourceLoader.exists("res://scenes/player/playerXR_Desktop/desktop_interaction.gd"):
		check(false, "Desktop programming interaction is not implemented")
		return true
	player = load("res://scenes/player/playerXR_Desktop/PlayerXR_Desktop.tscn").instantiate()
	root.add_child(player)
	interaction = player.get_node("DesktopInteraction")
	# Real XRTools panel and real SubViewport; headless cannot await frame_post_draw.
	panel = load("res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn").instantiate()
	panel.input_keyboard = false
	panel.position = Vector3(0, 1.58, -2)
	root.add_child(panel)
	surface = panel.get_node("Viewport")
	surface.size = Vector2i(800, 600)
	var content := Control.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(content)
	await process_frame
	check(interaction.enter_programming(panel), "nearby panel accepts programming")
	check(interaction.is_programming(), "programming state entered")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "programming releases the cursor")
	var camera: Camera3D = player.get_node("XRCamera3D")
	var before := camera.transform
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(150, 70)
	interaction._input(motion)
	check(camera.transform.is_equal_approx(before), "mouse does not rotate camera while programming")
	var body = player.get_node("PlayerBody")
	var movement: Node = player.get_node("XRToolsDesktopMovementDirect")
	Input.action_press("desktop_forward")
	body.ground_control_velocity = Vector2.ZERO
	movement.physics_movement(0.016, body, false)
	check(body.ground_control_velocity == Vector2.ZERO, "WASD cannot move during programming")
	Input.action_release("desktop_forward")
	interaction.exit_programming()
	check(not interaction.is_programming(), "exiting restores exploration")
	check(interaction.is_exploring(), "exiting restores captured-look state, including headless")
	Input.action_press("desktop_forward")
	body.ground_control_velocity = Vector2.ZERO
	movement.physics_movement(0.016, body, false)
	check(body.ground_control_velocity.length() > 0.0, "WASD moves while exploring")
	body.ground_control_velocity = Vector2.ZERO
	movement.physics_movement(0.016, body, true)
	check(body.ground_control_velocity == Vector2.ZERO, "disabled body cannot move")
	Input.action_release("desktop_forward")
	interaction._input(motion)
	check(not camera.transform.is_equal_approx(before), "mouse rotates camera while exploring")
	camera.transform = before
	panel.position.z = -20
	check(not interaction.enter_programming(panel), "distant panel cannot be activated")
	panel.position.z = -2
	return true

func test_text_entry_and_cancel() -> bool:
	if interaction == null:
		return true
	interaction.enter_programming(panel)
	var field := LineEdit.new()
	field.size = Vector2(400, 60)
	surface.get_node("Content").add_child(field)
	field.grab_focus()
	interaction._input(key_event(KEY_E))
	check(interaction.is_programming(), "E does not exit while a text field has focus")
	interaction._input(key_event(KEY_ESCAPE))
	check(not interaction.is_programming(), "Escape always exits programming")
	interaction.enter_programming(panel)
	interaction._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not interaction.is_programming(), "focus loss cancels programming")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus loss leaves OS cursor usable")
	field.queue_free()
	return true

func test_mouse_release() -> bool:
	if interaction == null:
		return true
	interaction.enter_programming(panel)
	var control := Button.new()
	control.size = Vector2(surface.size)
	var clicks := [0]
	control.pressed.connect(func(): clicks[0] += 1)
	surface.get_node("Content").add_child(control)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	button.position = root.get_visible_rect().size * 0.5
	var motion := InputEventMouseMotion.new()
	motion.position = button.position
	interaction._input(motion)
	interaction._input(button)
	check(interaction.pointer_pressed, "left click starts one pointer press")
	button.pressed = false
	interaction._input(button)
	check(clicks[0] == 1, "one desktop click activates one real GUI button exactly once")
	button.pressed = true
	interaction._input(button)
	interaction.exit_programming()
	control.queue_free()
	check(not interaction.pointer_pressed, "exiting releases a held mouse button")
	check(not surface.gui_is_dragging(), "exiting cancels native GUI dragging")
	return true

func test_removed_panel() -> bool:
	var temporary = load("res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn").instantiate()
	temporary.input_keyboard = false
	temporary.position = panel.position
	root.add_child(temporary)
	check(interaction.enter_programming(temporary), "temporary panel opens")
	temporary.queue_free()
	await process_frame
	await physics_frame
	interaction._physics_process(0.016)
	check(interaction.is_exploring(), "removed panel restores exploration instead of trapping cursor")
	return true

func test_no_hardware() -> bool:
	check(not root.use_xr, "root viewport never uses XR hardware")
	var hardware := XRServer.find_interface("OpenXR")
	check(hardware == null or not hardware.is_initialized(), "OpenXR remains uninitialized")
	return true
