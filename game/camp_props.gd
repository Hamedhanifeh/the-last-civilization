extends RefCounted

const WOOD = preload("res://game/camp_wood.gdshader")
const CANVAS = preload("res://game/camp_canvas.gdshader")
const HARD_SURFACE = preload("res://game/camp_hard_surface.gdshader")
const TERRAIN_ATLAS = preload("res://assets/art/terrain-atlas.png")
const SURFACE_ATLAS = preload("res://assets/art/surface-atlas.png")

# Static scenery shares a handful of unit meshes. Only the people and the fire move.
var forms: Dictionary
var groups: Dictionary = {}
var materials: Dictionary = {}
var placement := Transform3D.IDENTITY

func _init() -> void:
	var crown := CylinderMesh.new()
	crown.top_radius = 0.035
	crown.bottom_radius = 0.5
	crown.height = 1.0
	crown.radial_segments = 7
	var drum := CylinderMesh.new()
	drum.top_radius = 0.5
	drum.bottom_radius = 0.5
	drum.height = 1.0
	drum.radial_segments = 12
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	var bevel := beveled_box()
	var rock := angular_mesh([-0.4, -0.19, 0.10, 0.42], [0.31, 0.52, 0.45, 0.26], 7)
	var pine := angular_mesh([-0.47, -0.39, -0.19, 0.50], [0.37, 0.53, 0.37, 0.027], 9)
	forms = {"box": BoxMesh.new(), "ball": sphere, "cone": crown, "drum": drum,
		"tent": PrismMesh.new(), "trim": bevel, "wood": bevel, "lamp": bevel, "grass": crown,
		"asphalt": bevel, "concrete": bevel, "enamel": bevel, "soil": bevel, "rock": rock, "pine": pine}
	for key: String in forms:
		groups[key] = []

func add(shape: String, position: Vector3, size: Vector3, tint: String, rotation := Vector3.ZERO) -> void:
	groups[shape].append([placement * transform_at(position, size, rotation), Color(tint)])

func box(position: Vector3, size: Vector3, tint: String, yaw := 0.0) -> void:
	add("box", position, size, tint, Vector3(0, yaw, 0))

func timber(position: Vector3, size: Vector3, tint: String, yaw := 0.0) -> void:
	add("wood", position, size, tint, Vector3(0, yaw, 0))

func beam(start: Vector3, end: Vector3, thickness: float, tint: String, shape := "box") -> void:
	var axis := end - start
	var direction := axis.normalized()
	var side := Vector3.FORWARD if absf(direction.dot(Vector3.FORWARD)) < 0.98 else Vector3.RIGHT
	var cross := direction.cross(side).normalized()
	var basis := Basis(cross * thickness, axis, cross.cross(direction) * thickness)
	groups[shape].append([placement * Transform3D(basis, (start + end) * 0.5), Color(tint)])

func model(parent: Node3D, shape: String, position: Vector3, size: Vector3, tint: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = forms[shape]
	if not materials.has(tint):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(tint)
		material.roughness = 0.89
		materials[tint] = material
	part.material_override = materials[tint]
	parent.add_child(part)
	part.transform = transform_at(position, size, Vector3.ZERO)
	return part

func finish(parent: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	var wood_material := ShaderMaterial.new()
	wood_material.shader = WOOD
	wood_material.set_shader_parameter("surface_atlas", SURFACE_ATLAS)
	var canvas_material := ShaderMaterial.new()
	canvas_material.shader = CANVAS
	canvas_material.set_shader_parameter("surface_atlas", SURFACE_ATLAS)
	var asphalt_material := hard_surface(TERRAIN_ATLAS, Vector2(0, 0.5), 4.7, 0.83)
	var concrete_material := hard_surface(TERRAIN_ATLAS, Vector2(0.5, 0.5), 3.14, 0.74)
	var enamel_material := hard_surface(SURFACE_ATLAS, Vector2(0, 0.5), 1.1, 0.28)
	var soil_material := hard_surface(SURFACE_ATLAS, Vector2(0.5, 0.5), 1.67, 0.57)
	var lamp_material := material.duplicate() as StandardMaterial3D
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("e4a653")
	lamp_material.emission_energy_multiplier = 0.6
	for shape: String in groups:
		var items: Array = groups[shape]
		if items.is_empty():
			continue
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = forms[shape]
		batch.instance_count = items.size()
		for index in range(items.size()):
			batch.set_instance_transform(index, items[index][0])
			batch.set_instance_color(index, items[index][1])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = batch
		match shape:
			"wood": instance.material_override = wood_material
			"lamp": instance.material_override = lamp_material
			"tent": instance.material_override = canvas_material
			"asphalt": instance.material_override = asphalt_material
			"concrete": instance.material_override = concrete_material
			"enamel": instance.material_override = enamel_material
			"soil": instance.material_override = soil_material
			_: instance.material_override = material
		if shape == "grass":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)

func hard_surface(atlas: Texture2D, tile: Vector2, size: float, strength: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = HARD_SURFACE
	material.set_shader_parameter("terrain_atlas", atlas)
	material.set_shader_parameter("quadrant", tile)
	material.set_shader_parameter("tile_size", size)
	material.set_shader_parameter("blend_amount", strength)
	return material

func transform_at(position: Vector3, size: Vector3, rotation: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(rotation).scaled_local(size), position)

func beveled_box() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[float] = [-0.5, -0.44, 0.44, 0.5]
	for normal: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var x := Vector3.FORWARD if absf(normal.z) < 0.9 else Vector3.UP
		var y := x.cross(normal)
		for row in range(3):
			for column in range(3):
				var a := normal * 0.5 + x * grid[column] + y * grid[row]
				var b := normal * 0.5 + x * grid[column + 1] + y * grid[row]
				var c := normal * 0.5 + x * grid[column + 1] + y * grid[row + 1]
				var d := normal * 0.5 + x * grid[column] + y * grid[row + 1]
				for point: Vector3 in [a, b, c, a, c, d]:
					var core := point.clamp(Vector3.ONE * -0.44, Vector3.ONE * 0.44)
					var rounded_normal := (point - core).normalized()
					surface.set_normal(rounded_normal)
					surface.add_vertex(core + rounded_normal * 0.06)
	return surface.commit()

func angular_mesh(heights: Array[float], radii: Array[float], sides: int) -> ArrayMesh:
	var rings: Array[PackedVector3Array] = []
	for row in range(heights.size()):
		var ring := PackedVector3Array()
		for side in range(sides):
			var angle := TAU * side / sides + row * 0.055
			var radius := radii[row] * (0.92 + 0.12 * sin(side * 3.54 + row))
			ring.append(Vector3(cos(angle) * radius, heights[row] + 0.055 * sin(side * 1.76 + row), sin(angle) * radius))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in range(sides):
		var next := (side + 1) % sides
		for row in range(rings.size() - 1):
			var low := rings[row]
			var high := rings[row + 1]
			for point: Vector3 in [low[side], low[next], high[side], low[next], high[next], high[side]]:
				surface.set_smooth_group(-1)
				surface.add_vertex(point)
		for point: Vector3 in [Vector3.UP * heights[0], rings[0][next], rings[0][side],
			Vector3.UP * heights[-1], rings[-1][side], rings[-1][next]]:
			surface.set_smooth_group(-1)
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()
