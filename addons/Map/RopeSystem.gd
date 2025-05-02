extends Path3D
class_name RopeSystem

@export_range(3, 200, 1) var number_of_segments = 10
@export_range(3, 50, 1) var mesh_sides = 6
@export var rope_thickness = 0.1
@export var max_rope_length = 10.0
@export var material: Material
@export var player1_path: NodePath
@export var player2_path: NodePath

@onready var mesh := $CSGPolygon3D
@onready var player1: CharacterBody3D = get_node(player1_path) if player1_path else null
@onready var player2: CharacterBody3D = get_node(player2_path) if player2_path else null

var segments: Array = []
var joints: Array = []
var curve_points: Array = []
var rope_active = false
var rope_initialized = false

func _ready() -> void:
	# Wait until both players are assigned before creating the rope
	if player1 == null or player2 == null:
		# We'll create the rope when both players are assigned
		return
	
	# Add the CSGPolygon3D if it doesn't exist
	if !has_node("CSGPolygon3D"):
		mesh = CSGPolygon3D.new()
		mesh.name = "CSGPolygon3D"
		add_child(mesh)
		mesh.mode = CSGPolygon3D.MODE_PATH
		mesh.path_node = get_path()
		mesh.path_interval = 0.1
		mesh.path_joined = false
	
	initialize_rope()

# Called to set up the rope when players are assigned - only happens once
func initialize_rope() -> void:
	# Return if either player isn't set
	if player1 == null or player2 == null or rope_initialized:
		return
	
	# Store position and rotation
	var position_buffer = position
	var rotation_buffer = rotation
	rotation = Vector3.ZERO
	position = Vector3.ZERO
	
	# Calculate rope points
	var start_pos = player1.global_position
	var end_pos = player2.global_position
	var distance = start_pos.distance_to(end_pos)
	
	# Create a new curve
	curve = Curve3D.new()
	
	# Calculate rope path with natural droop
	var num_points = number_of_segments + 1
	
	for i in num_points:
		var t = float(i) / float(num_points - 1)
		var pos = start_pos.lerp(end_pos, t)
		
		# Add more natural droop if players are close
		if distance < max_rope_length * 0.8:
			# Calculate midpoint droop
			var droop_factor = 1.0 - (distance / max_rope_length)
			var max_droop = 0.5  # Maximum droop as a factor of distance
			
			# Create a parabolic droop (highest in the middle)
			var droop_amount = sin(t * PI) * droop_factor * max_droop * distance
			pos.y -= droop_amount
		
		curve_points.append(pos)
	
	# Create rope segments that will follow physics
	for i in number_of_segments:
		# Create rigidbodies for each segment
		segments.append(RigidBody3D.new())
		add_child(segments[i])
		
		# Position rigidbodies between the points
		segments[i].position = curve_points[i] + (curve_points[i+1] - curve_points[i])/2
		
		# Create collision shape
		var col_shape = CollisionShape3D.new()
		segments[i].add_child(col_shape)
		
		# Add capsule shape
		col_shape.shape = CapsuleShape3D.new()
		col_shape.shape.radius = rope_thickness
		col_shape.shape.height = (curve_points[i+1] - curve_points[i]).length()
		
		# Orient the segment properly
		var look_pos = curve_points[i+1]
		segments[i].look_at_from_position(segments[i].position + Vector3(0.001, 0, -0.001), look_pos)
		segments[i].rotation.x += PI/2
		
		# Set physics properties for natural rope behavior
		segments[i].mass = 0.05  # Lighter mass for less influence on players
		segments[i].linear_damp = 3.0  # Higher damping for less bouncing
		segments[i].angular_damp = 3.0
		segments[i].gravity_scale = 1.0
		segments[i].continuous_cd = true
		segments[i].contact_monitor = true
		segments[i].max_contacts_reported = 4
		segments[i].collision_layer = 2  # Set to a layer that doesn't collide with players but collides with the environment
		segments[i].collision_mask = 1  # Collide with the environment
		
		# Create joint for this segment
		joints.append(PinJoint3D.new())
		add_child(joints[i])
		joints[i].position = curve_points[i]
		
		# Connect joints to segments
		if i > 0:
			joints[i].node_a = segments[i-1].get_path()
			joints[i].node_b = segments[i].get_path()
			
			# Softer joint settings for slack
			#joints[i].set_param(PinJoint3D.PARAM_BIAS, 0.1)  # Low bias for more slack
			joints[i].set_param(PinJoint3D.PARAM_DAMPING, 1.0)
			#joints[i].set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, 99999.0)  # Never break
	
	# Add end joint - connects last segment to second player
	var end_joint = PinJoint3D.new()
	add_child(end_joint)
	end_joint.position = curve_points[number_of_segments]
	end_joint.node_a = segments[number_of_segments - 1].get_path()
	end_joint.node_b = player2.get_path()
	#end_joint.set_param(PinJoint3D.PARAM_BIAS, 0.1)
	end_joint.set_param(PinJoint3D.PARAM_DAMPING, 1.0)
	#end_joint.set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, 99999.0)
	joints.append(end_joint)
	
	# First joint - connects first player to first segment
	joints[0].node_a = player1.get_path()
	joints[0].node_b = segments[0].get_path()
	#joints[0].set_param(PinJoint3D.PARAM_BIAS, 0.1)
	joints[0].set_param(PinJoint3D.PARAM_DAMPING, 1.0)
	#joints[0].set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, 99999.0)
	
	# Create the visual mesh
	var shape = PackedVector2Array()
	for i in mesh_sides:
		shape.append(Vector2(sin(2*PI*(i+1)/mesh_sides), cos(2*PI*(i+1)/mesh_sides)) * rope_thickness)
	
	mesh.polygon = shape
	if material != null:
		mesh.material = material
	
	# Make all objects top level to avoid transformation issues
	for segment in segments:
		segment.top_level = true
		segment.position += position_buffer
	
	for joint in joints:
		joint.top_level = true
		joint.position += position_buffer
	
	# Reset transform
	rotation = rotation_buffer
	rope_active = true
	rope_initialized = true  # Mark as initialized to prevent recreation
	
	# Initialize curve for visualization
	curve.clear_points()
	for point in curve_points:
		curve.add_point(point)

func _physics_process(delta: float) -> void:
	if !rope_active:
		return
	
	# Check if players are still valid
	if !is_instance_valid(player1) or !is_instance_valid(player2):
		rope_active = false
		return
	
	# Handle rope tension only when distance exceeds max length
	handle_rope_tension()
	
	# Update curve positions for visualization
	update_rope_visualization()

func handle_rope_tension() -> void:
	var current_distance = player1.global_position.distance_to(player2.global_position)
	
	# Only apply force if the distance exceeds the maximum rope length
	if current_distance > max_rope_length:
		var direction = (player2.global_position - player1.global_position).normalized()
		var excess = current_distance - max_rope_length
		
		# Apply force distribution based on whether players are grounded
		# If both are in air, distribute the force
		if !player1.is_on_floor() and !player2.is_on_floor():
			player1.global_position += direction * (excess * 0.5)
			player2.global_position -= direction * (excess * 0.5)
		# If player1 is on floor but player2 is not, only move player2
		elif player1.is_on_floor() and !player2.is_on_floor():
			player2.global_position -= direction * excess
		# If player2 is on floor but player1 is not, only move player1
		elif !player1.is_on_floor() and player2.is_on_floor():
			player1.global_position += direction * excess
		# If both are on floor, do a more gentle adjustment
		else:
			player1.global_position += direction * (excess * 0.25)
			player2.global_position -= direction * (excess * 0.25)

func update_rope_visualization() -> void:
	if curve and segments.size() > 0:
		# Update curve for visualization
		curve.clear_points()
		
		# Add player1 position
		curve.add_point(player1.global_position)
		
		# Add segment positions
		for i in segments.size():
			if is_instance_valid(segments[i]):
				var segment_pos = segments[i].global_position
				var segment_basis = segments[i].transform.basis
				var segment_shape = segments[i].get_child(0).shape
				
				# Add points at the ends of each segment
				if i == 0:
					var start_point = segment_pos + segment_basis.y * (segment_shape.height/2)
					curve.add_point(start_point)
				
				var end_point = segment_pos - segment_basis.y * (segment_shape.height/2)
				curve.add_point(end_point)
		
		# Add player2 position
		curve.add_point(player2.global_position)

# Called from outside to assign players
func set_players(p1: CharacterBody3D, p2: CharacterBody3D) -> void:
	player1 = p1
	player2 = p2
	player1_path = get_path_to(p1)
	player2_path = get_path_to(p2)
	
	if !rope_initialized:
		initialize_rope()
