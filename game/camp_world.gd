extends Node3D

const Props = preload("res://game/camp_props.gd")
const Developed = preload("res://game/developed_camp.gd")
const Starter = preload("res://game/starter_camp.gd")
const GROUND = preload("res://game/camp_terrain.gdshader")
const TARGETS := {
	"woodcutter": Vector3(4.3, 0, 1.43),
	"stone_gatherer": Vector3(8.05, 0, -1.14),
	"forager": Vector3(-2.74, 0, 6.16),
	"water_carrier": Vector3(-6.78, 0, 4.17),
	"idle": Vector3(0.4, 0, 1.0),
}
const STARTER_TARGETS := {
	"woodcutter": Vector3(3.72, 0, 3.49),
	"stone_gatherer": Vector3(8.37, 0, 1.28),
	"forager": Vector3(-2.39, 0, 6.37),
	"water_carrier": Vector3(-6.27, 0, 4.51),
	"idle": Vector3(0.4, 0, 1.0),
}
const SHIRTS := ["aa6d3d", "ba9047", "7291a2", "99749b", "a88967", "a85d4b"]
const WOODS := ["b0804e", "a7774c", "c08b56", "967047", "ac8055"]
const LEAVES := ["67864a", "537c43", "7c994d", "7d963d"]
const BORDER := [
	Vector3(-14.2, 0, -1.4), Vector3(-11.8, 0, -6.2), Vector3(-5.8, 0, -10.3),
	Vector3(1.6, 0, -10.4), Vector3(9.7, 0, -7.1), Vector3(13.8, 0, -2.1),
	Vector3(13.8, 0, 2.2), Vector3(10.4, 0, 5.9), Vector3(4.2, 0, 8.8),
	Vector3(-3.4, 0, 9.2), Vector3(-10.7, 0, 6.5), Vector3(-14.2, 0, 3.0),
]

var props := Props.new()
var rng := RandomNumberGenerator.new()
var workers: Array[Node3D] = []
var destinations: Array[Vector3] = []
var worker_jobs: Array[String] = []
var walking_paths: Array[PackedVector3Array] = []
var path_steps: Array[int] = []
var arms: Array[Node3D] = []
var legs: Array[Array] = []
var tools: Array[Dictionary] = []
var sparks: Array[MeshInstance3D] = []
var outer_flame: MeshInstance3D
var inner_flame: MeshInstance3D
var fire_light: OmniLight3D
var age := 0.0
var developed_art := false

func populate(people: Array, is_developed := false) -> void:
	developed_art = is_developed
	rng.seed = 442
	lighting()
	ground()
	surroundings()
	build_border()
	tent(Vector3(-5.77, 0, -3.54), "59779b", "adad9d", 0.68, 1.17, true)
	var yellow_tent := Vector3(-2.52, 0, -7.47) if developed_art else Vector3(-0.8, 0, -6.25)
	tent(yellow_tent, "cba259", "d3b984", 0.49, 1.08)
	if not developed_art:
		tent(Vector3(3.93, 0, -3.62), "557ba6", "9baba4", 0.53, 0.65)
	var settlement: Developed = Developed.new() if developed_art else Starter.new()
	settlement.name = "DevelopedSettlement" if developed_art else "StarterSettlement"
	add_child(settlement)
	settlement.populate(props)
	campfire(Vector3(0, 0, 0.35))
	var interior_trees := [Vector3(-10.1, 0, -1.7), Vector3(-5.1, 0, -7.10)]
	if developed_art:
		interior_trees.append_array([Vector3(3.52, 0, 1.29), Vector3(-9.15, 0, 5.88), Vector3(1.38, 0, -4.05)])
	else:
		interior_trees.append_array([Vector3(-3.45, 0, 2.61), Vector3(5.25, 0, -6.90), Vector3(-11.12, 0, 1.15)])
	for pos: Vector3 in interior_trees:
		tree(pos, 0.66)
	for index in range(18):
		var side: Vector3 = BORDER[index % BORDER.size()]
		var next: Vector3 = BORDER[(index + 1) % BORDER.size()]
		var point := side.lerp(next, 0.28 + float(index % 3) * 0.16)
		rock(point * 0.941, rng.randf_range(0.34, 0.63))
	for pos: Vector3 in [Vector3(-7.9, 0, -2.4), Vector3(-10.4, 0, 5.05), Vector3(-5.65, 0, 6.1),
		Vector3(1.14, 0, 3.22), Vector3(1.34, 0, 7.25), Vector3(10.9, 0, 1.6), Vector3(7.4, 0, -4.9)]:
		flower_patch(pos)
	props.finish(self)
	for index in range(people.size()):
		add_person(index)
		assign_job(index, people[index]["job"])

func assign_job(person: int, job: String) -> void:
	worker_jobs[person] = job
	var tool_role := job
	if job == "builder":
		tool_role = "stone_gatherer"
	elif job == "farmer":
		tool_role = "forager"
	for key: String in tools[person]:
		tools[person][key].visible = key == tool_role
	destinations[person] = work_target(person, job)
	walking_paths[person] = PackedVector3Array()
	path_steps[person] = 0

func work_target(person: int, job: String) -> Vector3:
	var offset := Vector3((person % 3 - 1) * 0.57, 0, floorf(person / 3.0) * 0.55)
	if job in ["idle", "builder", "farmer"]:
		job = "idle"
		offset = Vector3(-1.6 + (person % 2) * 2.68, 0, 0.22)
	var target: Vector3 = TARGETS[job] if developed_art else STARTER_TARGETS[job]
	return target + offset

func set_walking_path(person: int, path: PackedVector3Array) -> void:
	walking_paths[person] = path
	path_steps[person] = 0
	var pos := workers[person].position
	destinations[person] = Vector3(pos.x, 0, pos.z) if path.is_empty() else path[-1]

func _process(delta: float) -> void:
	age += delta
	if is_instance_valid(outer_flame):
		outer_flame.scale.y = 0.96 + sin(age * 11.0) * 0.13 + cos(age * 6.0) * 0.14
		inner_flame.scale.y = 0.73 + sin(age * 9.0 + 0.7) * 0.08
		fire_light.light_energy = 1.31 + sin(age * 9.0) * 0.15
	for index in range(sparks.size()):
		var progress := fposmod(age * 0.75 + index * 0.16, 1.0)
		sparks[index].position = Vector3(sin(age * 4.0 + index) * progress * 0.30,
			0.48 + progress * 1.05, 0.35 + cos(index * 5.0 + age) * progress * 0.27)
		sparks[index].scale = Vector3.ONE * (0.085 * (1.0 - progress))
	for index in range(workers.size()):
		var person := workers[index]
		var position := Vector3(person.position.x, 0, person.position.z)
		var path := walking_paths[index]
		var next := path_steps[index]
		while next < path.size() and position.distance_squared_to(path[next]) < 0.01:
			next += 1
		path_steps[index] = next
		var target := path[next] if next < path.size() else destinations[index]
		var direction := target - position
		var walking := direction.length_squared() > 0.01
		var stride := sin(age * 13.5 + index)
		if walking:
			person.position = position.move_toward(target, delta * 2.5)
			person.rotation.y = lerp_angle(person.rotation.y, atan2(direction.x, direction.z), minf(delta * 10, 1))
			person.position.y = absf(stride) * 0.061
		else:
			person.position.y = 0
		legs[index][0].rotation.x = stride * (0.48 if walking else 0.0)
		legs[index][1].rotation.x = -legs[index][0].rotation.x
		var works := worker_jobs[index] != "idle"
		arms[index].rotation.x = stride * 0.50 if walking else sin(age * 4.5 + index) * (0.7 if works else 0.10)

func ground() -> void:
	var tile := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(104, 104)
	tile.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = GROUND
	mat.set_shader_parameter("terrain_atlas", Props.TERRAIN_ATLAS)
	tile.material_override = mat
	add_child(tile)

func lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -28, 0)
	sun.light_color = Color("fff2dc")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 62
	add_child(sun)
	var light := WorldEnvironment.new()
	light.environment = Environment.new()
	light.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	light.environment.ambient_light_color = Color("cfdbf2")
	light.environment.ambient_light_energy = 0.48
	add_child(light)

func build_border() -> void:
	for index in range(BORDER.size()):
		var from: Vector3 = BORDER[index]
		var to: Vector3 = BORDER[(index + 1) % BORDER.size()]
		if index == 7:
			var left := from.lerp(to, 0.24)
			var right := from.lerp(to, 0.86)
			fence(from, left)
			gate(left, right)
			fence(right, to)
		else:
			fence(from, to)

func fence(from: Vector3, to: Vector3, height := 1.33) -> void:
	var delta := to - from
	var yaw := atan2(-delta.z, delta.x)
	var plank_count := maxi(2, roundi(from.distance_to(to) / 0.33))
	var metal := rng.randi_range(1, plank_count - 1) if plank_count > 7 else -10
	for index in range(plank_count):
		var pos := from.lerp(to, (index + 0.5) / plank_count)
		var length := height + rng.randf_range(-0.16, 0.19)
		var sheet := absi(index - metal) < 2
		props.add("enamel" if sheet else "wood", pos + Vector3(0, length * 0.5, 0), Vector3(0.341, length, 0.13),
			["687c86", "788e98"][index % 2] if sheet else WOODS[index % WOODS.size()], Vector3(0, yaw, 0))
	var normal := outside_normal(yaw, (from + to) * 0.5)
	for y in [height * 0.29, height * 0.78]:
		var shift := normal * 0.10 + Vector3(0, y, 0)
		props.beam(from + shift, to + shift, 0.094, "8e653d", "wood")
	var posts := maxi(1, ceili(from.distance_to(to) / 2.9))
	for index in range(posts):
		var pos := from.lerp(to, float(index) / posts)
		props.timber(pos + Vector3(0, height * 0.53, 0), Vector3(0.23, height * 1.10, 0.26), "775638", yaw)
		if index == 0 and height < 1.5:
			lantern_at(pos + Vector3.UP * (height + 0.24), yaw, 0.66)

func gate(from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var yaw := atan2(-delta.z, delta.x)
	fence(from, to, 1.52)
	for pos: Vector3 in [from, to]:
		props.box(pos + Vector3(0, 0.87, 0), Vector3(0.40, 1.74, 0.42), "586265", yaw)
		props.box(pos + Vector3(0, 1.80, 0), Vector3(0.53, 0.20, 0.55), "b9a27c", yaw)
		lantern_at(pos + Vector3.UP * 2.05, yaw, 1.0)
	var center := (from + to) * 0.5
	var normal := outside_normal(yaw, center)
	var sign_center := center + Vector3(0, 0.94, 0) + normal * 0.22
	props.box(sign_center - Vector3.UP * 0.08, Vector3(1.64, 1.51, 0.09), "8a6349", yaw)
	props.box(sign_center + normal * 0.06, Vector3(1.21, 1.04, 0.075), "a4543f", yaw)
	var right := delta.normalized()
	for hand in [-1, 1]:
		props.beam(sign_center - right * 0.26 * hand + Vector3.DOWN * 0.29 + normal * 0.12,
			sign_center + right * 0.26 * hand + Vector3.UP * 0.29 + normal * 0.12, 0.080, "f6d8a0")
	var rail_pos := center + normal * 0.26
	for level in [0.32, 0.67, 1.71]:
		props.beam(rail_pos - right * 1.62 + Vector3.UP * level, rail_pos + right * 1.62 + Vector3.UP * level, 0.19, "665043", "wood")
		for index in range(8):
			var stripe: Vector3 = rail_pos + right * (-1.43 + index * 0.40) + normal * 0.119 + Vector3.UP * level
			props.add("trim", stripe, Vector3(0.17, 0.18, 0.024), "d0ab60", Vector3(0, yaw, 0.43))
	for side in [-1, 1]:
		var banner: Vector3 = center + right * side * 1.97 + normal * 0.27
		props.box(banner + Vector3.UP * 0.98, Vector3(0.42, 0.82, 0.1), "ad5744", yaw)
		props.beam(banner + Vector3.UP * 0.70 - right * 0.12 + normal * 0.071,
			banner + Vector3.UP * 0.70 + right * 0.12 + normal * 0.071, 0.036, "edcf9d")

func lantern_at(pos: Vector3, yaw: float, size: float) -> void:
	props.add("lamp", pos, Vector3(0.28, 0.29, 0.28) * size, "f8d084", Vector3(0, yaw, 0))
	props.add("trim", pos + Vector3.UP * 0.17 * size, Vector3(0.39, 0.11, 0.40) * size, "79644d", Vector3(0, yaw, 0))
	props.add("trim", pos - Vector3.UP * 0.16 * size, Vector3(0.36, 0.078, 0.36) * size, "79644d", Vector3(0, yaw, 0))
	for x in [-1, 1]:
		for z in [-1, 1]:
			var shift := Basis(Vector3.UP, yaw) * Vector3(x * 0.15, 0, z * 0.15) * size
			props.box(pos + shift, Vector3(0.043, 0.34, 0.043) * size, "71503b", yaw)

func outside_normal(yaw: float, center: Vector3) -> Vector3:
	var normal := Vector3(sin(yaw), 0, cos(yaw))
	return normal if normal.dot(center) >= 0 else -normal

func tent(pos: Vector3, canvas: String, trim: String, yaw: float, size: float, medical := false, batch: Props = null) -> void:
	if batch == null:
		batch = props
	var axis := Basis(Vector3.UP, yaw)
	var peak := Vector3(0, 2.03, 0) * size
	batch.add("tent", pos + Vector3.UP * size, Vector3(2.84, 2.02, 2.83) * size, canvas, Vector3(0, yaw, 0))
	batch.add("tent", pos + axis * Vector3(0, 0.9, 1.44) * size, Vector3(2.46, 1.85, 0.04) * size, trim, Vector3(0, yaw, 0))
	batch.add("tent", pos + axis * Vector3(0, 0.63, 1.465) * size, Vector3(1.17, 1.28, 0.055) * size, "34362b", Vector3(0, yaw, 0))
	for side in [-1, 1]:
		batch.beam(pos + axis * (peak + Vector3(0, 0, 1.48 * size)),
			pos + axis * Vector3(side * 1.46, 0.035, 1.65) * size, 0.083 * size, trim)
		var peg := pos + axis * Vector3(side * 1.9, 0.12, 1.97) * size
		batch.beam(pos + axis * Vector3(side * 0.97, 0.72, 1.31) * size, peg, 0.031, "c7af7b")
		batch.box(peg, Vector3(0.11, 0.27, 0.10), "79613d", yaw)
	batch.beam(pos + axis * (peak + Vector3(0, 0, -1.55 * size)),
		pos + axis * (peak + Vector3(0, 0, 1.55 * size)), 0.061, trim)
	if medical:
		batch.beam(pos + axis * Vector3(-0.72, 1.04, -0.36) * size,
			pos + axis * Vector3(-0.72, 1.04, 0.42) * size, 0.10, "bcc6bd")
		batch.beam(pos + axis * Vector3(-0.41, 1.48, 0.03) * size,
			pos + axis * Vector3(-1.03, 0.60, 0.03) * size, 0.097, "bcc6bd")
	if batch == props:
		crate(pos + axis * Vector3(-1.84, 0, 0.92) * size, 0.56 * size)
		crate(pos + axis * Vector3(-2.47, 0, 0.88) * size, 0.69 * size)

func draw_construction(kind: String, center: Vector3, span: Vector2, finished: bool) -> Node3D:
	var model := Node3D.new()
	add_child(model)
	model.position = center
	var batch := Props.new()
	if finished and kind == "farm":
		var field := Starter.new()
		model.add_child(field)
		field.props = batch
		batch.placement = Transform3D(Basis.from_scale(Vector3(span.x / 4.4, 1, span.y / 3.8)), Vector3(0, 0, -0.19))
		field.starter_garden()
	elif finished:
		tent(Vector3.ZERO, "be9258", "e2c39b", 0.0, 0.73, false, batch)
	else:
		batch.add("soil", Vector3.UP * 0.08, Vector3(span.x - 0.13, 0.16, span.y - 0.13), "8b725b")
		for x in [-1, 1]:
			for z in [-1, 1]:
				var corner := Vector3(x * (span.x * 0.5 - 0.18), 0.45, z * (span.y * 0.5 - 0.18))
				batch.timber(corner, Vector3(0.15, 0.89, 0.15), "ad8151")
			batch.beam(Vector3(x * (span.x * 0.5 - 0.18), 0.48, -span.y * 0.5 + 0.2),
				Vector3(x * (span.x * 0.5 - 0.18), 0.48, span.y * 0.5 - 0.2), 0.10, "b38a62", "wood")
		batch.timber(Vector3(-0.44, 0.27, 0.25), Vector3(1.15, 0.25, 0.63), "ab7750", 0.15)
	batch.finish(model)
	return model

func crate(pos: Vector3, size: float) -> void:
	props.box(pos + Vector3.UP * size * 0.49, Vector3(size, size * 0.98, size * 0.92), "ad7c4a")
	for x in [-0.39, 0.39]:
		props.box(pos + Vector3(x, 0.51, 0.478) * size, Vector3(0.13, 1.0, 0.09) * size, "d5a876")
	for y in [0.1, 0.89]:
		props.box(pos + Vector3(0, y, 0.478) * size, Vector3(1.03, 0.13, 0.09) * size, "c3925e")
	props.beam(pos + Vector3(-0.38, 0.15, 0.514) * size, pos + Vector3(0.38, 0.86, 0.514) * size,
		size * 0.088, "ddae72")

func campfire(pos: Vector3) -> void:
	for index in range(11):
		var angle := TAU * index / 11.0
		rock(pos + Vector3(cos(angle) * 0.57, 0, sin(angle) * 0.57), 0.27)
	for index in range(4):
		var shift := Vector3(cos(index * TAU / 4), 0, sin(index * TAU / 4)) * 0.34
		props.beam(pos + shift + Vector3.UP * 0.11, pos - shift + Vector3.UP * 0.31, 0.16, "70482e", "drum")
	for bench: Vector3 in [Vector3(-1.52, 0, -0.07), Vector3(1.62, 0, 0.32), Vector3(-0.05, 0, 1.29)]:
		props.box(pos + bench + Vector3.UP * 0.22, Vector3(1.07, 0.29, 0.40), "9d6b42", bench.x * 0.53)
	outer_flame = props.model(self, "cone", pos + Vector3.UP * 0.58, Vector3(0.73, 1.07, 0.73), "ff9a37")
	inner_flame = props.model(self, "cone", pos + Vector3(0.03, 0.57, 0.15), Vector3(0.34, 0.65, 0.32), "ffe995")
	for index in range(6):
		sparks.append(props.model(self, "ball", pos + Vector3.UP, Vector3.ONE * 0.06, "fff0ac"))
	fire_light = OmniLight3D.new()
	fire_light.omni_range = 3.4
	fire_light.light_color = Color("ffab57")
	add_child(fire_light)
	fire_light.position = pos + Vector3.UP * 0.65

func surroundings() -> void:
	road(Vector3(-10, 0, -14.0), Vector3(19, 0, -9.3), 3.5)
	road(Vector3(19, 0, -9.3), Vector3(16, 0, 3.2), 3.7)
	road(Vector3(16, 0, 3.2), Vector3(-1.4, 0, 17.0), 3.7)
	for stripe in range(6):
		props.box(Vector3(16.1 + stripe * 0.44, 0.095, -5.3 + stripe * 0.10),
			Vector3(0.22, 0.015, 0.71), "d7d5c5", -0.24)
	bridge(Vector3(7.0, -0.52, -12.08))
	bus(Vector3(13.1, 0.81, -9.58), 0.26)
	ruin(Vector3(-16.12, 0, 9.55), 4.1)
	ruin(Vector3(-15.48, 0, 11.55), 2.5)
	ruin(Vector3(-8.5, 0, -14.8), 3.8)
	for pos: Vector3 in [Vector3(-15.6,0,-6.1),Vector3(-13.4,0,-9.7),Vector3(-12.3,0,-11.7),
		Vector3(-7.3,0,-10.6),Vector3(-3.5,0,-12.6),Vector3(-1,0,-11.4),Vector3(2.3,0,-12.8),
		Vector3(-14.6,0,5.4),Vector3(-9.05,0,10.4),Vector3(-7.15,0,12.6),Vector3(10.3,0,9.4),
		Vector3(12.8,0,8.2),Vector3(15.1,0,7.0),Vector3(16.5,0,5.3),Vector3(17.4,0,8.5),
		Vector3(15.5,0,-6.0),Vector3(10.2,0,-8.5),Vector3(19.2,0,-7.1)]:
		tree(pos, rng.randf_range(0.85, 1.39))
	for pos: Vector3 in [Vector3(-15.45, 0, -10.1), Vector3(-11.25, 0, -10.75),
		Vector3(3.6, 0, -12.05), Vector3(5.27, 0, -11.93), Vector3(15.15, 0, 11.15),
		Vector3(17.45, 0, 12.10), Vector3(-10.2, 0, 13.5)]:
		tree(pos, rng.randf_range(0.76, 1.24))
	for index in range(900):
		var x := rng.randf_range(-19.2, 19.2)
		var z := rng.randf_range(-14.3, 12.9)
		var point := Vector3(x, 0, z)
		if lies_on_path(point) or ((x > 13.7 and z > -9 and z < 5) or z < -11.7):
			continue
		var height := rng.randf_range(0.05, 0.23)
		props.add("grass", point + Vector3.UP * height * 0.48, Vector3(0.32, height, 0.24),
			LEAVES[index % LEAVES.size()], Vector3(0, index, 0.28))
		if index % 11 == 0:
			for petal in range(3):
				props.add("ball", point + Vector3(float(petal) * 0.105, height + 0.045, -0.075),
					Vector3(0.10, 0.11, 0.10), "e6d6a4")
		elif index % 21 == 0:
			rock(point, 0.17)
	for index in range(9):
		var base := Vector3(13.5 + (index % 3) * 0.36, 0, -3.6 + index * 0.17)
		rock(base, rng.randf_range(0.26, 0.71))
	props.box(Vector3(14.3, 0.89, -3.45), Vector3(0.17, 1.78, 0.18), "665a47")
	props.box(Vector3(12.85, 0.85, -3.45), Vector3(0.17, 1.70, 0.18), "665a47")
	props.box(Vector3(13.58, 1.84, -3.45), Vector3(2.24, 1.05, 0.15), "856a56")
	props.box(Vector3(13.58, 1.84, -3.35), Vector3(2.03, 0.87, 0.05), "b0a084")
	for index in range(10):
		var height := 0.12 + sin(index * 2.1) * sin(index * 2.1) * 0.46
		props.box(Vector3(12.74 + index * 0.18, 1.49 + height * 0.5, -3.313), Vector3(0.13, height, 0.013), "786b59")

func lies_on_path(point: Vector3) -> bool:
	if Vector3(point.x, 0, point.z * 1.3).length() < 3.1:
		return true
	for end in [Vector3(-8, 0, 4), Vector3(6.4, 0, 6.2), Vector3(-4.2, 0, -5.9), Vector3(8, 0, -1.8)]:
		if point.distance_to(Geometry3D.get_closest_point_to_segment(point, Vector3(0, 0, 0.4), end)) < 1.05:
			return true
	return false

func road(start: Vector3, end: Vector3, width: float) -> void:
	var angle := atan2(end.x - start.x, end.z - start.z)
	var span := start.distance_to(end)
	var center := (start + end) * 0.5 + Vector3.UP * 0.016
	props.box(center, Vector3(width + 0.36, 0.07, span + width * 0.22), "9a9786", angle)
	props.add("asphalt", center + Vector3.UP * 0.028, Vector3(width, 0.065, span + width * 0.18), "767977", Vector3(0, angle, 0))
	for index in range(1, ceili(span / 2.2)):
		var point := start.lerp(end, index * 2.2 / span)
		props.box(point + Vector3.UP * 0.089, Vector3(0.085, 0.008, 0.95), "d6ceaf", angle)

func bridge(pos: Vector3) -> void:
	for index in range(3):
		var shift := pos + Vector3(-7.0 + index * 3.7, 0, index * 0.62)
		props.add("concrete", shift + Vector3.UP * 1.22, Vector3(0.56, 2.44, 0.68), "879394")
		props.add("concrete", shift + Vector3.UP * 2.45, Vector3(4.02, 0.53, 2.79), "7b878a", Vector3(0, -0.15, 0))
		props.add("concrete", shift + Vector3(0, 2.82, -1.2), Vector3(3.76, 0.40, 0.25), "8b9898", Vector3(0, -0.15, 0))
		for vine in range(3):
			props.add("ball", shift + Vector3(vine * 0.25, 1.7 + vine * 0.39, 0.82),
				Vector3(0.36, 0.93, 0.43), LEAVES[vine])
	props.add("concrete", pos + Vector3(6.11, 1.14, 2.43), Vector3(3.8, 0.41, 2.31), "a0a5a2", Vector3(0, -0.1, -0.41))
	props.add("concrete", pos + Vector3(3.34, 1.84, 1.79), Vector3(2.7, 0.42, 2.64), "899696", Vector3(0, -0.22, 0.26))

func bus(pos: Vector3, yaw: float) -> void:
	var previous := props.placement
	props.placement = Transform3D(Basis.from_euler(Vector3(-0.03, yaw, -0.23)), pos)
	props.add("trim", Vector3(0, 0.59, 0), Vector3(3.98, 0.73, 1.30), "b37f64")
	props.add("trim", Vector3(0, 1.16, 0), Vector3(3.91, 0.49, 1.26), "afa293")
	props.add("trim", Vector3(-0.06, 1.44, 0), Vector3(3.92, 0.18, 1.34), "c3a88b")
	for side in [-1, 1]:
		props.add("trim", Vector3(0, 0.86, 0.66 * side), Vector3(3.76, 0.083, 0.025), "c39e78")
		for panel in range(6):
			var x := -1.56 + panel * 0.605
			props.add("trim", Vector3(x, 1.14, 0.64 * side), Vector3(0.47, 0.38, 0.04), "524b47")
			props.add("trim", Vector3(x, 1.15, 0.66 * side), Vector3(0.40, 0.30, 0.038), "52626a" if panel % 3 != 2 else "627078")
		for x: float in [-1.22, 1.24]:
			props.add("drum", Vector3(x, 0.26, 0.66 * side), Vector3(0.49, 0.195, 0.49), "474846", Vector3(PI * 0.5, 0, 0))
			props.add("drum", Vector3(x, 0.26, 0.76 * side), Vector3(0.23, 0.047, 0.23), "939089", Vector3(PI * 0.5, 0, 0))
		props.add("trim", Vector3(2.0, 0.63, 0.43 * side), Vector3(0.08, 0.12, 0.23), "cabc91")
	props.add("trim", Vector3(1.966, 1.13, 0), Vector3(0.071, 0.39, 0.99), "566971")
	props.add("trim", Vector3(1.995, 0.38, 0), Vector3(0.24, 0.17, 1.30), "6c6860")
	props.placement = previous

func ruin(pos: Vector3, height: float) -> void:
	props.add("concrete", pos + Vector3.UP * 0.18, Vector3(4.2, 0.36, 2.93), "83908b")
	for floor_index in [0.43, 0.94]:
		props.add("concrete", pos + Vector3.UP * height * floor_index, Vector3(4.22, 0.34, 2.80), "a3aaa2")
	for index in range(3):
		var position := pos + Vector3(index * 1.73 - 1.73, 0, 1.2)
		props.add("concrete", position + Vector3.UP * height / 2.0, Vector3(0.38, height, 0.44), "949e98")
		for vine in range(4):
			props.add("ball", position + Vector3(0.19 + vine * 0.09, height * 0.55 + vine * 0.39, 0.37),
				Vector3(0.48, 0.65, 0.38), LEAVES[(index + vine) % LEAVES.size()])
	props.add("concrete", pos + Vector3(-1.77, height * 0.43, -0.57), Vector3(0.42, height * 0.86, 2.83), "939c96")

func tree(pos: Vector3, size: float) -> void:
	props.add("drum", pos + Vector3.UP * 0.63 * size, Vector3(0.22, 1.26, 0.23) * size, "775938")
	for level in range(3):
		var width := (1.74 - level * 0.32) * size
		var tip := pos + Vector3.UP * (1.38 + level * 0.68) * size
		props.add("pine", tip, Vector3(width, 1.65 * size, width), LEAVES[level], Vector3(0, level * 0.53, 0))

func rock(pos: Vector3, size: float) -> void:
	props.add("rock", pos + Vector3.UP * size * 0.40,
		Vector3(1.32, 0.95, 1.10) * size, ["a0a898", "818b81", "b1aea0"][rng.randi_range(0, 2)],
		Vector3(0.18, rng.randf_range(0, TAU), 0.2))

func flower_patch(pos: Vector3) -> void:
	for index in range(4):
		var stem := pos + Vector3(sin(index * 2.40) * 0.27, 0, cos(index * 2.40) * 0.31)
		var height := 0.17 + index * 0.057
		props.beam(stem, stem + Vector3.UP * height, 0.018, "6b8a47", "drum")
		props.add("grass", stem + Vector3(0.040, 0.08, 0.03), Vector3(0.22, 0.19, 0.14), "718d41", Vector3(0, index * 2.1, 0.72))
		for petal in range(5):
			var angle := TAU * petal / 5.0
			var offset := Vector3(sin(angle) * 0.069, height, cos(angle) * 0.069)
			props.add("ball", stem + offset, Vector3(0.113, 0.060, 0.108), "f1e6c2")
		props.add("ball", stem + Vector3.UP * (height + 0.018), Vector3(0.078, 0.066, 0.075), "e9be6c")

func add_person(index: int) -> void:
	var resident := Node3D.new()
	resident.name = "Survivor%d" % (index + 1)
	add_child(resident)
	var start := [Vector3(-3.63, 0, -1.95), Vector3(7.65, 0, -1.09), Vector3(-2.82, 0, 5.53),
		Vector3(-6.81, 0, 3.89), Vector3(-1.2, 0, 0.18), Vector3(1.72, 0, 0.85)]
	if not developed_art:
		start = [Vector3(-1.82, 0, -2.36), Vector3(8.53, 0, 0.76), Vector3(-2.54, 0, 6.05),
			Vector3(-6.09, 0, 4.30), Vector3(-1.2, 0, 0.18), Vector3(1.72, 0, 0.85)]
	resident.position = start[index]
	resident.scale = Vector3.ONE * 1.13
	resident.rotation.y = [0.72, -0.15, 0.14, -0.29, 0.68, -0.85][index]
	var shirt: String = SHIRTS[index]
	var skin := "d6a77f" if index % 3 == 0 else "dfb38b"
	props.model(resident, "ball", Vector3(0, 0.57, 0), Vector3(0.49, 0.51, 0.36), shirt)
	props.model(resident, "box", Vector3(0.06, 0.6, 0.178), Vector3(0.14, 0.11, 0.04), "d3ac76")
	props.model(resident, "box", Vector3(0, 0.39, 0.14), Vector3(0.38, 0.060, 0.14), "6d5339")
	props.model(resident, "ball", Vector3(0, 1.00, 0.014), Vector3(0.468, 0.429, 0.405), skin)
	for eye in [-1, 1]:
		props.model(resident, "ball", Vector3(eye * 0.076, 1.021, 0.194), Vector3(0.039, 0.045, 0.034), "473c33")
		props.model(resident, "ball", Vector3(eye * 0.202, 0.98, 0.064), Vector3(0.089, 0.094, 0.107), skin)
	props.model(resident, "ball", Vector3(0, 0.987, 0.207), Vector3(0.069, 0.066, 0.065), "d6a27b")
	var hat: String = ["543e2e", "e7b652", "e6bf77", "c0c4be", "a2abb4", "ba5e46"][index]
	props.model(resident, "ball", Vector3(0, 1.169, -0.023), Vector3(0.469, 0.24, 0.44), hat)
	if index == 2:
		props.model(resident, "drum", Vector3(0, 1.099, 0.018), Vector3(0.64, 0.050, 0.58), "d7ad69")
		props.model(resident, "drum", Vector3(0, 1.128, 0.015), Vector3(0.450, 0.039, 0.43), "a47b4f")
	elif index != 0:
		props.model(resident, "drum", Vector3(0, 1.114, 0.031), Vector3(0.51, 0.058, 0.47), hat)
	else:
		props.model(resident, "ball", Vector3(-0.12, 1.08, -0.061), Vector3(0.184, 0.25, 0.26), hat)
		props.model(resident, "ball", Vector3(0.04, 1.13, 0.135), Vector3(0.26, 0.12, 0.15), hat)
	props.model(resident, "trim", Vector3(0, 0.63, -0.184), Vector3(0.31, 0.34, 0.17), "8d6c4d")
	for strap in [-1, 1]:
		props.model(resident, "trim", Vector3(strap * 0.127, 0.62, 0.142), Vector3(0.043, 0.30, 0.078), "b99870")
	var arm := attachment(resident, Vector3(0.25, 0.72, 0.03))
	props.model(arm, "ball", Vector3(0.009, -0.095, 0.01), Vector3(0.15, 0.24, 0.15), shirt)
	props.model(arm, "ball", Vector3(0.022, -0.22, 0.075), Vector3(0.12, 0.21, 0.12), skin)
	props.model(resident, "ball", Vector3(-0.245, 0.55, 0.08), Vector3(0.13, 0.32, 0.13), shirt)
	arms.append(arm)
	tools.append(job_tools(arm))
	var pair := []
	for side in [-1, 1]:
		var limb := attachment(resident, Vector3(side * 0.114, 0.42, 0))
		pair.append(limb)
		props.model(limb, "ball", Vector3(0, -0.175, 0), Vector3(0.18, 0.34, 0.18), "47505a")
		props.model(limb, "box", Vector3(0, -0.365, 0.056), Vector3(0.177, 0.104, 0.24), "544237")
	legs.append(pair)
	workers.append(resident)
	destinations.append(Vector3.ZERO)
	worker_jobs.append("")
	walking_paths.append(PackedVector3Array())
	path_steps.append(0)

func attachment(parent: Node3D, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position = pos
	return pivot

func job_tools(arm: Node3D) -> Dictionary:
	var axe := attachment(arm, Vector3(0.08, -0.27, 0.13))
	props.model(axe, "drum", Vector3(0, 0.02, 0), Vector3(0.065, 0.44, 0.065), "a1764c")
	props.model(axe, "box", Vector3(0.057, 0.16, 0.005), Vector3(0.20, 0.094, 0.098), "84908a")
	var hammer := attachment(arm, Vector3(0.08, -0.26, 0.09))
	props.model(hammer, "drum", Vector3(0, 0, 0), Vector3(0.064, 0.34, 0.06), "916445")
	props.model(hammer, "box", Vector3(0.01, 0.15, 0.012), Vector3(0.23, 0.13, 0.10), "8b9695")
	var basket := attachment(arm, Vector3(0.051, -0.37, 0.076))
	props.model(basket, "drum", Vector3.ZERO, Vector3(0.28, 0.20, 0.24), "ba8853")
	props.model(basket, "ball", Vector3(0, 0.105, 0), Vector3(0.21, 0.12, 0.19), "94aa59")
	var bucket := attachment(arm, Vector3(0.052, -0.37, 0.09))
	props.model(bucket, "drum", Vector3.ZERO, Vector3(0.27, 0.27, 0.27), "6d939f")
	props.model(bucket, "drum", Vector3(0, 0.14, 0), Vector3(0.25, 0.040, 0.25), "a1bfbd")
	return {"woodcutter": axe, "stone_gatherer": hammer, "forager": basket, "water_carrier": bucket}
