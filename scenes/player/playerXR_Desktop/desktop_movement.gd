extends XRToolsMovementProvider
## Named desktop actions, with no hardware-XR startup dependency.

@export var order := 10
@export var max_speed := 3.0
@export var strafe := true
@export var input_forward := "desktop_forward"
@export var input_backward := "desktop_backward"
@export var input_left := "desktop_left"
@export var input_right := "desktop_right"

func physics_movement(_delta: float, player_body: XRToolsPlayerBody, disabled: bool):
	var interaction := get_parent().get_node_or_null("DesktopInteraction")
	if disabled or not enabled or not interaction or not interaction.is_exploring():
		player_body.velocity.x = 0.0
		player_body.velocity.z = 0.0
		return false
	var direction := Input.get_vector(input_left, input_right, input_backward, input_forward)
	player_body.ground_control_velocity += direction * max_speed
	player_body.ground_control_velocity = player_body.ground_control_velocity.limit_length(max_speed)
	return false
