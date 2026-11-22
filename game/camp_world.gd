extends Node3D

const TARGETS := {
	"woodcutter": Vector3(-7.7, 0, -3.5),
	"stone_gatherer": Vector3(7.5, 0, -3.9),
	"forager": Vector3(6.1, 0, 4.8),
	"water_carrier": Vector3(-7.4, 0, 5.1),
	"idle": Vector3(0.5, 0, 1.0),
}
const CLOTHES := ["c98b54", "50788a", "a46a66", "699182", "bbab5d", "976d8c"]

var materials: Dictionary = {}
var workers: Array[Node3D] = []
var destinations: Array[Vector3] = []
var worker_jobs: Array[String] = []
var fire: MeshInstance3D
var age := 0.0
var rng := RandomNumberGenerator.new()

func populate(people: Array) -> void:
	rng.seed = 401
	lighting()
	landscape()
	settlement()
	for index in range(people.size()):
		var person := Node3D.new()
		person.name = "Survivor%d" % (index + 1)
		add_child(person)
		person.position = Vector3(-2.6 + index * 0.72, 0, 2.5)
		box(person, Vector3(0, 0.57, 0), Vector3(0.34, 0.45, 0.26), CLOTHES[index])
		ball(person, Vector3(0, 0.96, 0), Vector3(0.29, 0.32, 0.29), "d2a17c")
		ball(person, Vector3(0, 1.07, 0), Vector3(0.32, 0.13, 0.31), "544438")
		box(person, Vector3(-0.10, 0.20, 0), Vector3(0.12, 0.39, 0.15), "333e3e")
		box(person, Vector3(0.10, 0.20, 0), Vector3(0.12, 0.39, 0.15), "333e3e")
		box(person, Vector3(0.22, 0.56, 0), Vector3(0.10, 0.31, 0.13), CLOTHES[index])
		workers.append(person)
		destinations.append(Vector3.ZERO)
		worker_jobs.append("")
		assign_job(index, people[index]["job"])

func assign_job(person: int, job: String) -> void:
	worker_jobs[person] = job
	var offset := Vector3((person % 3 - 1) * 0.48, 0, (person / 3) * 0.36)
	if job == "idle":
		offset = Vector3((person % 3 - 1) * 0.82, 0, person * 0.31)
	destinations[person] = TARGETS[job] + offset

func _process(delta: float) -> void:
	age += delta
	if is_instance_valid(fire):
		fire.scale.y = 0.90 + sin(age * 9.0) * 0.10
	for index in range(workers.size()):
		var person := workers[index]
		var position := Vector3(person.position.x, 0, person.position.z)
		var direction := destinations[index] - position
		if direction.length_squared() > 0.007:
			person.position = position.move_toward(destinations[index], delta * 2.25)
			person.rotation.y = atan2(direction.x, direction.z)
			person.position.y = absf(sin(age * 17.0 + index)) * 0.08
		else:
			person.position.y = 0
		var working := worker_jobs[index] != "idle"
		person.get_child(5).rotation.x = sin(age * 5.0 + index) * (0.65 if working else 0.08)

func lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -32, 0)
	sun.light_color = Color("ffddb8")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	var world_light := WorldEnvironment.new()
	world_light.environment = Environment.new()
	world_light.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_light.environment.ambient_light_color = Color("c4d8cf")
	world_light.environment.ambient_light_energy = 0.7
	add_child(world_light)

func landscape() -> void:
	box(self, Vector3(0, -0.65, 0), Vector3(110, 0.6, 100), "506452")
	box(self, Vector3(0, -0.35, 0), Vector3(36, 0.66, 27), "6e8156")
	box(self, Vector3(0, -0.16, -11), Vector3(39, 0.32, 3.1), "696e67")
	for index in range(12):
		box(self, Vector3(-16 + index * 3.05, 0.015, -11), Vector3(1.22, 0.015, 0.08), "aaa791")
	box(self, Vector3(-12.6, -0.025, 3.5), Vector3(5.0, 0.10, 28), "466d72")
	for index in range(17):
		var ripple := box(self, Vector3(rng.randf_range(-14.6, -10.6), 0.045, rng.randf_range(-9, 15)),
			Vector3(rng.randf_range(0.35, 1.5), 0.015, 0.05), "79a39d")
		ripple.rotation.y = 0.1
	for index in range(42):
		var x := rng.randf_range(-19, 19)
		var z := rng.randf_range(-17, 15)
		if (absf(x) > 9.2 or z > 8.1 or z < -12.8) and not (x > -15.5 and x < -10.0 and z > -8.5):
			tree(Vector3(x, 0, z), rng.randf_range(0.7, 1.4))
	for index in range(36):
		var x := rng.randf_range(-9, 12)
		var z := rng.randf_range(-9, 11)
		if absf(x) > 8 or absf(z) > 7:
			ball(self, Vector3(x, 0.12, z), Vector3(0.38, 0.26, 0.45), "81935e")
	ruin(Vector3(4.4, 0, -14.4), 4.2)
	ruin(Vector3(10.7, 0, -14.1), 3.25)
	ruin(Vector3(-5.9, 0, -15.1), 3.6)
	path(Vector3(-8, 0, 5.3), Vector3(7.5, 0, 4.8), 1.05)
	path(Vector3(-7.8, 0, -3.6), Vector3(0.5, 0, 2.4), 0.9)
	path(Vector3(0.5, 0, 2.4), Vector3(7.7, 0, -4.0), 0.92)
	path(Vector3(0.5, 0, 1.5), Vector3(0.6, 0, 6), 0.8)

func settlement() -> void:
	var clearing := CylinderMesh.new()
	clearing.top_radius = 3.9
	clearing.bottom_radius = 3.9
	clearing.height = 0.02
	clearing.radial_segments = 32
	mesh(self, clearing, Vector3(0.3, 0.014, 0.65), "b2a375")
	tent(Vector3(-3.7, 0, -2.0), "d9bd89")
	tent(Vector3(1.1, 0, -3.7), "a89970")
	for index in range(10):
		var angle := TAU * index / 10.0
		ball(self, Vector3(0.18 + cos(angle) * 0.55, 0.14, 0.1 + sin(angle) * 0.55),
			Vector3(0.37, 0.28, 0.31), "858378")
	var ember := CylinderMesh.new()
	ember.top_radius = 0.03
	ember.bottom_radius = 0.34
	ember.height = 0.78
	ember.radial_segments = 7
	fire = mesh(self, ember, Vector3(0.18, 0.44, 0.1), "efa74d")
	ball(self, Vector3(0.18, 0.29, 0.1), Vector3(0.39, 0.40, 0.37), "ffcf75")
	box(self, Vector3(-1.02, 0.25, 0.45), Vector3(0.52, 0.5, 0.52), "8e6e47")
	box(self, Vector3(-1.00, 0.15, 1.15), Vector3(0.38, 0.33, 0.45), "a58155")
	for index in range(4):
		tree(Vector3(-7.4 - (index % 2) * 1.28, 0, -5.2 - (index / 2) * 0.9), 0.95)
		var log_mesh := box(self, Vector3(-6.8 - (index % 2) * 0.40, 0.19 + (index / 2) * 0.23, -4.47),
			Vector3(0.33, 0.32, 1.5), "806046")
		log_mesh.rotation.y = 0.2
	for index in range(8):
		var boulder := ball(self, Vector3(rng.randf_range(7.5, 9.7), 0.43, rng.randf_range(-6.3, -4.7)),
			Vector3(1.04, rng.randf_range(0.65, 1.3), 0.90), "9a9b8e")
		boulder.rotation.y = index * 0.9
	for index in range(10):
		var bush := Vector3(5.5 + (index % 5) * 0.59, 0.24, 5.7 + (index / 5) * 0.58)
		ball(self, bush, Vector3(0.68, 0.52, 0.64), "5a7847")
		ball(self, bush + Vector3(0.12, 0.22, 0.10), Vector3(0.13, 0.15, 0.13), "c38b59")
	box(self, Vector3(-9.1, 0.12, 5.0), Vector3(2.5, 0.20, 1.12), "9e825c")
	box(self, Vector3(-8.1, 0.34, 5.8), Vector3(0.44, 0.65, 0.45), "5c827f")

func tent(pos: Vector3, color: String) -> void:
	var body := PrismMesh.new()
	body.size = Vector3(2.8, 2.06, 2.9)
	mesh(self, body, pos + Vector3(0, 1.03, 0), color)
	var door := PrismMesh.new()
	door.size = Vector3(1.30, 1.50, 0.04)
	mesh(self, door, pos + Vector3(0, 0.75, 1.466), "554c39")
	box(self, pos + Vector3(0, 0.10, 1.56), Vector3(1.10, 0.14, 0.37), "997b53")
	for side in [-1, 1]:
		box(self, pos + Vector3(side * 1.48, 0.15, 1.7), Vector3(0.12, 0.3, 0.12), "795c43")

func path(start: Vector3, end: Vector3, width: float) -> void:
	var center := (start + end) / 2.0 + Vector3(0, 0.007, 0)
	var strip := box(self, center, Vector3(width, 0.014, start.distance_to(end)), "a7996e")
	strip.rotation.y = atan2(end.x - start.x, end.z - start.z)

func tree(pos: Vector3, size: float) -> void:
	box(self, pos + Vector3(0, size * 0.64, 0), Vector3(0.31, 1.28, 0.30) * size, "6e5c47")
	for level in range(2):
		var crown := CylinderMesh.new()
		crown.top_radius = 0.12 * size
		crown.bottom_radius = (1.0 - level * 0.25) * size
		crown.height = 1.65 * size
		crown.radial_segments = 6
		mesh(self, crown, pos + Vector3(0, (1.50 + level * 0.78) * size, 0), "4e704f" if level == 0 else "5f8057")

func ruin(pos: Vector3, height: float) -> void:
	box(self, pos + Vector3(0, 0.25, 0), Vector3(4.3, 0.5, 3.1), "858d80")
	for index in range(3):
		var column := pos + Vector3(index * 1.66 - 1.66, 0, 1.18)
		box(self, column + Vector3(0, height * 0.5, 0), Vector3(0.47, height, 0.52), "90988c")
	box(self, pos + Vector3(0, height - 0.32, 0.68), Vector3(4.35, 0.34, 1.56), "949b8d")
	box(self, pos + Vector3(-1.62, height * 0.49, -0.53), Vector3(0.37, height * 0.98, 2.7), "7e887d")
	for index in range(3):
		ball(self, pos + Vector3(1.55, height * 0.72 - index * 0.46, 1.3), Vector3(0.62, 0.87, 0.5), "657e5d")

func box(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, color)

func ball(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radial_segments = 7
	shape.rings = 3
	var instance := mesh(parent, shape, pos, color)
	instance.scale = size
	return instance

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: String) -> MeshInstance3D:
	if not materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.roughness = 0.92
		materials[color] = material
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = materials[color]
	parent.add_child(instance)
	instance.position = pos
	return instance
