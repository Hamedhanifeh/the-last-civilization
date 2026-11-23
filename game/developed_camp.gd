extends Node3D

const Props = preload("res://game/camp_props.gd")
const WATER = preload("res://game/camp_water.gdshader")
const SMOKE = preload("res://game/camp_smoke.gdshader")
const BOARD_COLORS := ["875536", "95643e", "a16e45", "a9794e", "8d5e3d"]
const ROOF_COLORS := ["3e597c", "476388", "4d6b90", "43668c", "4b6c91"]
const PLANT_COLORS := ["687e37", "729c40", "87a94b", "557d36", "8aa048"]

var props: Props
var chimney := Vector3.ZERO
var plume: Array[MeshInstance3D] = []
var age := 0.0

func populate(batch: Props) -> void:
	props = batch
	place(Vector3(7.5, 0, -3.0), 0.52)
	building(5.4, 3.65, 2.31, "workshop")
	place(Vector3(2.15, 0, -6.93), 0.36)
	building(3.39, 2.67, 1.98, "radio")
	place(Vector3(8.83, 0, 3.31), 0.49)
	building(3.89, 2.36, 1.48, "storage")
	place(Vector3(-9.2, 0, 1.93), 0.17)
	waterworks()
	place(Vector3(-2.35, 0, 4.43), -0.35)
	farmland()
	place(Vector3(3.45, 0, 0.04), 0.40)
	work_supplies()
	place(Vector3(-3.83, 0, -0.62), -0.32)
	seed_box(Vector3.ZERO, 0.85, "d88046")
	props.placement = Transform3D.IDENTITY
	warm_light(Vector3(6.98, 1.28, -0.43), 3.15, 1.02)
	warm_light(Vector3(2.69, 1.10, -5.51), 2.23, 0.86)
	warm_light(Vector3(7.53, 0.94, 4.28), 2.55, 0.89)
	warm_light(Vector3(8.80, 1.58, 7.21), 2.46, 0.74)
	make_smoke()

func place(position: Vector3, yaw: float) -> void:
	props.placement = Transform3D(Basis(Vector3.UP, yaw), position)

func building(width: float, depth: float, eave: float, kind: String) -> void:
	var half := width * 0.5
	var front := depth * 0.5
	var peak := eave + width * 0.29
	var garage := kind == "workshop"
	var open_front := garage or kind == "storage"
	props.add("trim", Vector3(0, 0.14, 0), Vector3(width + 0.19, 0.27, depth + 0.32), "8d8173")
	var plank_count := ceili(width / 0.29)
	for index in range(plank_count):
		var a := (index + 0.5) / plank_count
		var x := lerpf(-half, half, a)
		var top := eave + (1.0 - absf(a * 2.0 - 1.0)) * (peak - eave)
		var opening := 0.0
		if open_front and absf(x) < (1.22 if garage else half * 0.75):
			opening = eave * 0.71
		var tint: String = BOARD_COLORS[index % BOARD_COLORS.size()]
		props.timber(Vector3(x, (top + opening) * 0.5, front), Vector3(width / plank_count - 0.012, top - opening, 0.18), tint)
		props.timber(Vector3(x, top * 0.5, -front), Vector3(width / plank_count - 0.012, top, 0.16), tint)
	var side_count := ceili(depth / 0.27)
	for side in [-1, 1]:
		for index in range(side_count):
			var position := Vector3(half * side, eave * 0.5, lerpf(-front, front, (index + 0.5) / side_count))
			props.timber(position, Vector3(0.17, eave, depth / side_count - 0.018), BOARD_COLORS[(index + side + 1) % BOARD_COLORS.size()], PI * 0.5)
		for end in [-1, 1]:
			props.timber(Vector3(half * side, eave * 0.52, front * end), Vector3(0.22, eave * 1.04, 0.24), "694932")
		props.beam(Vector3(half * side, eave + 0.03, -front - 0.27), Vector3(half * side, eave + 0.03, front + 0.27), 0.15, "776044", "wood")
		slanted_roof(half, front, eave, peak, side)
		props.beam(Vector3(half * side + 0.27 * side, eave - 0.05, front + 0.30), Vector3(0, peak + 0.06, front + 0.30), 0.155, "ab7650", "wood")
	props.beam(Vector3(0, peak + 0.065, -front - 0.31), Vector3(0, peak + 0.065, front + 0.31), 0.15, "607994", "trim")
	props.beam(Vector3(-half, eave + 0.05, front + 0.11), Vector3(half, eave + 0.05, front + 0.11), 0.18, "73472f", "wood")
	if garage:
		window_at(Vector3(-half - 0.13, 1.34, 0.20), PI * 1.5, 0.97, 0.75)
		window_at(Vector3(half - 0.62, 1.37, front + 0.118), 0.0, 0.68, 0.71)
		props.box(Vector3(0, eave * 0.73, front + 0.147), Vector3(2.70, 0.19, 0.2), "745039")
		workshop_sign(Vector3(0.18, eave + 0.50, front + 0.206))
		solar_array(Vector3(-half * 0.61, lerpf(eave, peak, 0.39) + 0.17, -0.42), atan2(peak - eave, half))
		var pipe := Vector3(half * 0.72, peak - 0.41, -front * 0.61)
		props.add("drum", pipe, Vector3(0.24, 1.77, 0.24), "555755")
		props.add("drum", pipe + Vector3.UP * 0.69, Vector3(0.38, 0.43, 0.38), "795745")
		props.add("drum", pipe + Vector3.UP * 0.92, Vector3(0.40, 0.16, 0.39), "515350")
		chimney = props.placement * (pipe + Vector3.UP * 1.0)
		props.box(Vector3(-0.6, 0.72, front - 0.37), Vector3(1.12, 0.19, 0.69), "7f6a54")
		props.add("trim", Vector3(-0.7, 0.93, front - 0.26), Vector3(0.33, 0.28, 0.46), "829094")
		seed_box(Vector3(half - 0.29, 0.10, front + 0.64), 0.51)
	elif kind == "radio":
		props.timber(Vector3(-0.48, 0.89, front + 0.122), Vector3(0.76, 1.40, 0.089), "674a36")
		window_at(Vector3(0.56, 1.19, front + 0.15), 0.0, 0.81, 0.7)
		var base := Vector3(-0.71, peak - 0.15, 0.06)
		props.beam(base, base + Vector3(-0.3, 0.68, 0.08), 0.074, "c5c0ac")
		props.add("ball", base + Vector3(-0.38, 0.76, 0.13), Vector3(0.83, 0.14, 0.79), "c7d0cf", Vector3(0.70, 0, -0.45))
		props.beam(Vector3(0.56, 0.94, -front - 0.29), Vector3(0.56, peak + 1.74, -front - 0.29), 0.093, "696f69", "trim")
		for row in range(4):
			var mark := peak + row * 0.44
			props.beam(Vector3(0.25, mark, -front - 0.29), Vector3(0.86, mark, -front - 0.29), 0.055, "879087")
		seed_box(Vector3(half - 0.29, 0.1, front + 0.53), 0.58)
	else:
		props.beam(Vector3(-half + 0.13, 0.78, front + 0.28), Vector3(half - 0.1, 0.78, front + 0.28), 0.14, "a1744a", "wood")
		for side in [-1, 1]:
			seed_box(Vector3(side * 0.75, 0.16, front - 0.17), 0.67)
			seed_box(Vector3(side * 0.77, 0.87, front - 0.21), 0.52)
		props.add("lamp", Vector3(-half + 0.28, eave * 0.85, front + 0.22), Vector3(0.17, 0.27, 0.18), "f3c170")
		props.add("trim", Vector3(half + 1.08, 0.56, front - 0.24), Vector3(1.59, 1.04, 1.44), "7e8b55")
		props.add("wood", Vector3(half + 1.04, 0.17, front - 0.24), Vector3(1.68, 0.25, 1.52), "9a7147")

func slanted_roof(half: float, front: float, eave: float, peak: float, side: int) -> void:
	var edge := Vector3(side * (half + 0.33), eave - 0.06, 0)
	var apex := Vector3(0, peak + 0.065, 0)
	var slope := (edge - apex).length()
	var angle := atan2(edge.y - apex.y, edge.x - apex.x)
	if side < 0:
		angle += PI
	var count := ceili((front * 2.0 + 0.56) / 0.24)
	for index in range(count):
		var z := lerpf(-front - 0.26, front + 0.26, (index + 0.5) / count)
		props.add("trim", (edge + apex) * 0.5 + Vector3(0, 0.03, z), Vector3(slope, 0.123, 0.26),
			ROOF_COLORS[index % ROOF_COLORS.size()], Vector3(0, 0, angle))
		if index % 2 == 0:
			props.beam(apex + Vector3(0, 0.108, z), edge + Vector3(0, 0.12, z), 0.046, "7393b4", "trim")

func window_at(position: Vector3, yaw: float, width: float, height: float) -> void:
	var axis := Basis(Vector3.UP, yaw)
	props.add("trim", position, Vector3(width + 0.18, height + 0.18, 0.12), "70492f", Vector3(0, yaw, 0))
	props.add("lamp", position + axis * Vector3(0, 0, 0.092), Vector3(width, height, 0.052), "efb35f", Vector3(0, yaw, 0))
	props.timber(position + axis * Vector3(0, 0, 0.14), Vector3(0.077, height, 0.081), "905f3a", yaw)
	props.timber(position + axis * Vector3(0, 0, 0.14), Vector3(width, 0.058, 0.08), "905f3a", yaw)
	props.timber(position + axis * Vector3(0, -height * 0.52, 0.126), Vector3(width + 0.21, 0.08, 0.23), "b47a4b", yaw)

func solar_array(center: Vector3, roll: float) -> void:
	var tilt := Basis(Vector3.BACK, roll)
	props.add("trim", center, Vector3(1.42, 0.12, 1.02), "a5b4bc", Vector3(0, 0, roll))
	for index in range(12):
		var shift := tilt * Vector3(-0.50 + (index % 4) * 0.335, 0.071, -0.333 + floorf(index / 4.0) * 0.33)
		props.add("trim", center + shift, Vector3(0.300, 0.037, 0.297), "315482" if index % 2 == 0 else "3b6592", Vector3(0, 0, roll))

func workshop_sign(pos: Vector3) -> void:
	props.add("trim", pos, Vector3(1.19, 0.88, 0.13), "d5b58a")
	props.add("trim", pos + Vector3(0, 0, 0.07), Vector3(1.04, 0.74, 0.05), "dfcda8")
	for side in [-1, 1]:
		props.beam(pos + Vector3(-0.23 * side, -0.27, 0.12), pos + Vector3(0.24 * side, 0.22, 0.12), 0.085, "85593c", "trim")
		props.beam(pos + Vector3(0.10 * side, 0.27, 0.12), pos + Vector3(0.35 * side, 0.10, 0.12), 0.105, "85593c", "trim")

func waterworks() -> void:
	for x in [-0.61, 0.61]:
		for z in [-0.53, 0.53]:
			props.timber(Vector3(x, 0.84, z), Vector3(0.22, 1.68, 0.23), "916643")
		props.beam(Vector3(x, 0.20, -0.48), Vector3(x, 1.46, 0.50), 0.14, "725237", "wood")
	props.timber(Vector3(0, 1.52, 0), Vector3(1.65, 0.24, 1.46), "b18459")
	props.add("drum", Vector3(0, 2.21, 0), Vector3(1.42, 1.21, 1.37), "487ba3")
	for y in [1.63, 1.76, 2.69, 2.81]:
		props.add("drum", Vector3(0, y, 0), Vector3(1.52, 0.075, 1.47), "89a8b5")
	props.add("drum", Vector3(0, 2.96, 0), Vector3(0.41, 0.20, 0.42), "6d909f")
	props.add("ball", Vector3(0.04, 2.21, 0.69), Vector3(0.19, 0.28, 0.065), "e1edeb")
	for x in [-1.33, -0.03, 1.34]:
		props.add("trim", Vector3(x, 0.29, 1.92), Vector3(1.27, 0.56, 0.26), "949586")
		props.add("trim", Vector3(x, 0.31, 3.26), Vector3(1.30, 0.59, 0.28), "9da093")
	for side in [-1, 1]:
		for row in range(3):
			props.add("trim", Vector3(side * 1.88, 0.33, 1.97 + row * 0.58), Vector3(0.28, 0.64, 0.62), "b0b1a0")
	var pool := PlaneMesh.new()
	pool.size = Vector2(3.62, 1.23)
	water_mesh(pool, Vector3(0, 0.46, 2.60), Vector3.ZERO, 0.58)
	props.beam(Vector3(0.02, 1.86, 0.55), Vector3(-0.94, 1.84, 0.87), 0.22, "778080", "drum")
	props.beam(Vector3(-0.95, 1.84, 0.87), Vector3(-0.95, 0.96, 1.38), 0.21, "657679", "drum")
	props.beam(Vector3(-0.95, 0.96, 1.38), Vector3(-0.95, 0.96, 2.07), 0.21, "7d8f91", "drum")
	var fall := QuadMesh.new()
	fall.size = Vector2(0.31, 0.68)
	water_mesh(fall, Vector3(-0.95, 0.70, 2.2), Vector3(0.41, 0, 0), 2.13)
	for index in range(6):
		props.add("ball", Vector3(-1.10 + index * 0.07, 0.51, 2.35 + (index % 3) * 0.09), Vector3(0.14, 0.06, 0.11), "b3e8e9")
	for index in range(2):
		props.add("drum", Vector3(1.08 + index * 0.49, 0.46, 0.78), Vector3(0.43, 0.90, 0.45), "4c7899")
		for y in [0.11, 0.84]:
			props.add("drum", Vector3(1.08 + index * 0.49, y, 0.78), Vector3(0.46, 0.059, 0.48), "a5b0a8")

func water_mesh(mesh: Mesh, local: Vector3, rotation: Vector3, speed: float) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = WATER
	material.set_shader_parameter("speed", speed)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	instance.transform = props.placement * Transform3D(Basis.from_euler(rotation), local)

func farmland() -> void:
	var plots := [Vector3(-2.25, 0, 0.46), Vector3(0.35, 0, -0.75), Vector3(2.60, 0, 0.32)]
	for plot in range(3):
		var pos: Vector3 = plots[plot]
		props.add("trim", pos + Vector3.UP * 0.10, Vector3(2.42, 0.20, 3.23), "73513b")
		for row in range(4):
			var row_pos := pos + Vector3(-0.83 + row * 0.54, 0.14, 0)
			props.add("trim", row_pos, Vector3(0.34, 0.185, 3.05), "876046" if row % 2 == 0 else "8a674b")
			for index in range(7):
				crop(row_pos + Vector3(sin(index * 2.21 + row) * 0.063, 0.08, -1.27 + index * 0.42), plot, row + index)
		for side in [-1, 1]:
			for y in [0.22, 0.48]:
				var rail := Vector3(0, y, side * 1.71)
				props.beam(pos + rail + Vector3.LEFT * 1.27, pos + rail + Vector3.RIGHT * 1.27, 0.085, "a47b51", "wood")
				var upright := Vector3(side * 1.29, y, 0)
				props.beam(pos + upright + Vector3.FORWARD * 1.71, pos + upright + Vector3.BACK * 1.71, 0.083, "b48a5a", "wood")
			for front in [-1.71, 0.0, 1.71]:
				props.timber(pos + Vector3(side * 1.31, 0.33, front), Vector3(0.15, 0.66, 0.15), "865b39")
	seed_box(Vector3(-2.7, 0, 2.23), 0.64, "d98748")
	seed_box(Vector3(1.34, 0, 2.42), 0.59, "c6643e")

func crop(pos: Vector3, kind: int, index: int) -> void:
	if kind == 1:
		var stem := 0.50 + float(index % 4) * 0.062
		props.add("cone", pos + Vector3(-0.076, stem * 0.59, 0.0), Vector3(0.13, stem, 0.13), "8b9a45", Vector3(0, 0, 0.33))
		props.add("ball", pos + Vector3(0.02, stem * 1.02, 0), Vector3(0.14, 0.28, 0.12), "d9b94f", Vector3(0, 0, -0.29))
		props.add("cone", pos + Vector3(0.10, stem * 0.46, 0), Vector3(0.19, stem * 0.74, 0.16), "799748", Vector3(0, 0, -0.42))
		return
	var fruit_height := 0.28 if kind == 0 else 0.52 + (index % 3) * 0.08
	if kind == 2:
		props.timber(pos + Vector3(0.09, fruit_height * 0.53, 0.02), Vector3(0.045, fruit_height * 1.21, 0.044), "9d7146")
	for leaf in range(4):
		var angle := leaf * TAU / 4.0 + index * 0.48
		var shift := Vector3(cos(angle) * 0.13, 0.10 + leaf * fruit_height * 0.18, sin(angle) * 0.13)
		props.add("ball", pos + shift, Vector3(0.29, 0.24, 0.25), PLANT_COLORS[(leaf + index) % 5])
	props.add("ball", pos + Vector3(0.075, fruit_height * 0.62, 0.125), Vector3(0.16, 0.155, 0.15),
		"d77a46" if kind == 2 else "9eb859")

func seed_box(pos: Vector3, size: float, contents := "") -> void:
	props.timber(pos + Vector3.UP * size * 0.27, Vector3(size, size * 0.53, size), "ad784b")
	for side in [-1, 1]:
		props.timber(pos + Vector3(side * size * 0.46, size * 0.51, 0), Vector3(size * 0.08, size * 0.13, size), "c6925b")
		props.timber(pos + Vector3(0, size * 0.51, size * 0.46 * side), Vector3(size, size * 0.13, size * 0.08), "c99763")
	if not contents.is_empty():
		for fruit in range(5):
			props.add("ball", pos + Vector3(-0.24 + (fruit % 3) * 0.23, 0.60, -0.16 + floorf(fruit / 3.0) * 0.29) * size,
				Vector3(0.25, 0.26, 0.25) * size, contents)

func work_supplies() -> void:
	for index in range(9):
		var start := Vector3(-0.8, 0.18 + floorf(index / 3.0) * 0.22, (index % 3) * 0.23)
		props.beam(start, start + Vector3(1.52, 0, 0), 0.26, "785133", "drum")
		props.add("ball", start - Vector3(0.016, 0, 0), Vector3(0.05, 0.24, 0.24), "c99b60")
	for index in range(3):
		props.add("trim", Vector3(-0.65 + index * 0.47, 0.15, 1.0), Vector3(0.61, 0.31, 0.39), "8e9b9a")

func make_smoke() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for index in range(6):
		var puff := MeshInstance3D.new()
		puff.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = SMOKE
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		plume.append(puff)
	update_smoke(0.0)

func warm_light(pos: Vector3, radius: float, strength: float) -> void:
	var light := OmniLight3D.new()
	light.omni_range = radius
	light.light_energy = strength
	light.light_color = Color("ffac55")
	add_child(light)
	light.position = pos

func _process(delta: float) -> void:
	update_smoke(delta)

func update_smoke(delta: float) -> void:
	age += delta
	for index in range(plume.size()):
		var progress := fposmod(age * 0.47 + index * 0.1667, 1.0)
		var puff := plume[index]
		puff.position = chimney + Vector3(-progress * 0.56 + sin(progress * 7.0) * 0.078, 0.08 + progress * 2.62, progress * 0.14)
		puff.scale = Vector3.ONE * (0.26 + progress * 1.11)
		puff.material_override.set_shader_parameter("opacity", sin(progress * PI) * 0.36)
