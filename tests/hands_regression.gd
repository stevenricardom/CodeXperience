extends SceneTree
## Run: Godot --headless --path . --script res://tests/hands_regression.gd
##
## Regresión de manos: seguimiento en espacio local de cámara sin depender de
## Q/E, retorno finito sin saltos, y poses (reposo / señalar / agarrar).

const LIMITER_PATH := "res://scenes/player/playerXR_Desktop/hand_limiter.gd"
const HAND_SCENE_PATH := "res://scenes/player/playerXR_Desktop/hands/stylized_hand.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player/playerXR_Desktop/PlayerXR_Desktop.tscn"

var passed := 0
var failed := 0
var origin: XROrigin3D
var camera: XRCamera3D
var interaction: Node
var right: XRController3D
var left: XRController3D
var right_hand: Node3D
var left_hand: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for test_name in ["test_tracking_without_qe", "test_return_finite_no_jumps", "test_pose_cycle", "test_left_hand_mirror", "test_visual_geometry", "test_scene_layout"]:
		if await call(test_name) != true:
			check(false, test_name + " did not finish")
	if is_instance_valid(origin):
		origin.queue_free()
	await process_frame
	print("Hands regression: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func _build_fixture() -> void:
	origin = XROrigin3D.new()
	origin.name = "Fixture"
	root.add_child(origin)
	camera = XRCamera3D.new()
	camera.name = "XRCamera3D"
	camera.position = Vector3(0.0, 1.6, 0.0)
	origin.add_child(camera)
	interaction = Node.new()
	interaction.name = "DesktopInteraction"
	interaction.set_script(load("res://tests/hands_fixture_interaction.gd"))
	origin.add_child(interaction)
	right = _make_controller(&"right_hand")
	right_hand = right.get_node("StylizedHand")
	left = _make_controller(&"left_hand")
	left_hand = left.get_node("StylizedHand")

func _make_controller(tracker: StringName) -> XRController3D:
	var controller := XRController3D.new()
	controller.tracker = tracker
	controller.set_script(load(LIMITER_PATH))
	origin.add_child(controller)
	var visual: Node3D = load(HAND_SCENE_PATH).instantiate() as Node3D
	visual.name = "StylizedHand"
	visual.handedness = -1 if tracker == &"left_hand" else 1
	controller.add_child(visual)
	return controller

func _advance(controller: XRController3D, steps: int, delta: float = 1.0 / 60.0) -> void:
	for _i in steps:
		controller.tick(delta)

func test_tracking_without_qe() -> bool:
	_build_fixture()
	await process_frame
	var source: String = FileAccess.get_file_as_string(LIMITER_PATH)
	check(not source.contains("KEY_Q") and not source.contains("KEY_E"), "limiter no reads Q/E keys")
	check(not source.contains("is_key_pressed"), "limiter does not poll key state")
	# Camera moved: hands must follow in camera-local space.
	camera.position = Vector3(1.0, 1.6, -2.0)
	_advance(right, 120)
	_advance(left, 120)
	var right_local: Vector3 = right.get_local_position()
	var left_local: Vector3 = left.get_local_position()
	check(right_local.is_finite() and left_local.is_finite(), "tracked positions are finite")
	check(right_local.x > 0.0 and left_local.x < 0.0, "hands stay on their own side")
	check(right_local.y < 0.0 and left_local.y < 0.0, "hands rest below the camera")
	check(right_local.z < 0.0 and left_local.z < 0.0, "hands stay in front of the camera")
	var world: Vector3 = camera.to_global(right_local)
	check(right.global_position.distance_to(world) < 0.001, "hand follows camera-local space")
	return true

func test_return_finite_no_jumps() -> bool:
	if right == null:
		return true
	# Snap the camera far away: in camera-local space the hand must glide, not teleport.
	camera.position = Vector3(-6.0, 1.6, 4.0)
	var max_step := 0.0
	var previous: Vector3 = right.get_local_position()
	for _i in 60:
		right.tick(1.0 / 60.0)
		var current: Vector3 = right.get_local_position()
		check(current.is_finite(), "hand position stays finite while returning")
		max_step = maxf(max_step, current.distance_to(previous))
		previous = current
	check(max_step < 0.2, "hand does not jump while returning (max step %.3f)" % max_step)
	# Converges to the rest pose without overshoot.
	var rest: Vector3 = right.get_rest_local()
	_advance(right, 600)
	var final: Vector3 = right.get_local_position()
	check(final.is_finite(), "final position is finite")
	check(final.distance_to(rest) < 0.05, "hand converges to rest pose")
	return true

func test_pose_cycle() -> bool:
	if right == null:
		return true
	interaction.set_programming(false)
	interaction.set_pointer_pressed(false)
	right.tick(1.0 / 60.0)
	check(right.hand_pose_name() == "idle", "idle pose when exploring")
	var idle_angle: float = right_hand.get_joint_angle(3)
	interaction.set_programming(true)
	interaction.set_pointer_pressed(false)
	_advance(right, 90)
	check(right.hand_pose_name() == "point", "point pose while programming")
	var point_angle: float = right_hand.get_joint_angle(3)
	check(not is_equal_approx(idle_angle, point_angle), "point pose changes finger angles")
	interaction.set_pointer_pressed(true)
	_advance(right, 90)
	check(right.hand_pose_name() == "grab", "grab pose while pointer is pressed")
	var grab_angle: float = right_hand.get_joint_angle(3)
	check(not is_equal_approx(point_angle, grab_angle), "grab pose changes finger angles")
	interaction.set_programming(false)
	interaction.set_pointer_pressed(false)
	_advance(right, 90)
	check(right.hand_pose_name() == "idle", "returns to idle after programming")
	# Poses must not move the camera nor the body.
	var camera_transform: Transform3D = camera.global_transform
	var body_transform: Transform3D = origin.global_transform
	_advance(right, 30)
	check(camera.global_transform.is_equal_approx(camera_transform), "pose animation does not move the camera")
	check(origin.global_transform.is_equal_approx(body_transform), "pose animation does not move the body")
	return true

func test_left_hand_mirror() -> bool:
	if left == null:
		return true
	var right_rest: Vector3 = right.get_rest_local()
	var left_rest: Vector3 = left.get_rest_local()
	check(is_equal_approx(right_rest.x, -left_rest.x), "rest positions are mirrored in X")
	var right_thumb: Vector3 = right_hand.get_thumb_local_position()
	var left_thumb: Vector3 = left_hand.get_thumb_local_position()
	check(not is_equal_approx(right_thumb.x, left_thumb.x), "thumb is mirrored between hands")
	check(right_hand.handedness == 1 and left_hand.handedness == -1, "handedness flag differs per hand")
	return true

func test_visual_geometry() -> bool:
	if right_hand == null:
		return true
	var meshes := 0
	var total := AABB()
	for node in _walk(right_hand):
		if node is MeshInstance3D:
			meshes += 1
			# Medimos en el espacio local de la mano (independiente de la vista).
			var box: AABB = right_hand.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
			check(box.position.is_finite() and box.size.is_finite(), "hand mesh bounds are finite")
			total = total.merge(box)
	check(meshes >= 15, "hand is built from many rounded parts (%d)" % meshes)
	check(total.size.x > 0.05 and total.size.x < 0.25, "hand width is plausible")
	check(total.size.z > 0.10 and total.size.z < 0.30, "hand length is plausible")
	# Los dedos deben arrancar dentro de la palma (silueta unida, no dedos sueltos).
	var palm: MeshInstance3D = right_hand.get_node("Palm")
	var palm_box: AABB = palm.global_transform * palm.get_aabb()
	for finger in ["Index_0", "Middle_0", "Ring_0", "Little_0"]:
		var joint: Node3D = right_hand.get_node(finger)
		check(palm_box.has_point(joint.global_position), "finger %s starts inside the palm" % finger)
	var thumb: Node3D = right_hand.get_node("Thumb")
	check(palm_box.has_point(thumb.global_position), "thumb starts inside the palm")
	return true

func _walk(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_walk(child))
	return out

func test_scene_layout() -> bool:
	var text: String = FileAccess.get_file_as_string(PLAYER_SCENE_PATH)
	check(text.contains("hands/stylized_hand.tscn"), "player uses the local stylized hands")
	check(not text.contains("right_hand_low.tscn") and not text.contains("left_hand_low.tscn"), "vendor hand meshes are not used")
	check(not text.contains("function_pickup.tscn"), "desktop FunctionPickup removed")
	var pointer_lines: PackedStringArray = text.split("\n")
	var pointer_count := 0
	var enabled_count := 0
	for line in pointer_lines:
		if line.contains("[node name=\"FunctionPointer\""):
			pointer_count += 1
		if line.strip_edges() == "enabled = false":
			enabled_count += 1
	check(pointer_count == 2, "both FunctionPointer nodes remain")
	check(enabled_count >= 2, "FunctionPointer stays disabled")
	return true
