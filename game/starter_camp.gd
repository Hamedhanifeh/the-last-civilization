extends "res://game/developed_camp.gd"

const SITE := Vector3(7.65, 0, -0.22)
const WELL := Vector3(-8.28, 0, 3.41)
const GARDEN := Vector3(-1.00, 0, 6.24)
const WOOD_PILE := Vector3(3.75, 0, 2.47)

func populate(batch: Props) -> void:
	props = batch
	place(WELL, 0.22)
	starter_water()
	place(GARDEN, -0.31)
	starter_garden()
	place(SITE, 0.52)
	worksite()
	place(WOOD_PILE, 0.30)
	work_supplies()
	props.placement = Transform3D.IDENTITY

func starter_water() -> void:
	for x in [-0.58, 0.58]:
		for z in [-0.52, 0.52]:
			props.timber(Vector3(x, 0.72, z), Vector3(0.16, 1.44, 0.17), "92643c")
		props.beam(Vector3(x, 0.19, -0.47), Vector3(x, 1.26, 0.49), 0.098, "725435", "wood")
	props.timber(Vector3(0, 1.40, 0), Vector3(1.43, 0.19, 1.30), "aa7950")
	props.add("drum", Vector3(0, 1.95, 0), Vector3(1.14, 1.03, 1.12), "487da6")
	for y in [1.44, 1.58, 2.39, 2.48]:
		props.add("drum", Vector3(0, y, 0), Vector3(1.22, 0.065, 1.20), "8fa9b5")
	props.add("drum", Vector3(0, 2.55, 0), Vector3(0.42, 0.13, 0.40), "627f94")
	props.add("ball", Vector3(0.025, 1.96, 0.56), Vector3(0.17, 0.24, 0.064), "e0f1ec")
	for x in [-2.08, -0.84]:
		for z in [-0.49, 0.58]:
			props.timber(Vector3(x, 0.82, z), Vector3(0.15, 1.67, 0.14), "9c6d46")
		props.beam(Vector3(x, 1.66, -0.61), Vector3(x, 1.51, 0.83), 0.10, "986c46", "wood")
	for index in range(4):
		props.add("enamel", Vector3(-2.10 + index * 0.415, 1.68, 0.09), Vector3(0.44, 0.105, 1.61),
			ROOF_COLORS[index], Vector3(-0.105, 0.0, -0.035))
	barrel(Vector3(-2.20, 0, 0.99), "a0774c", 0.70)
	barrel(Vector3(0.82, 0, 1.31), "7496a2", 0.54)
	var bowl := Vector3(-0.29, 0, 1.34)
	props.add("trim", bowl + Vector3.UP * 0.12, Vector3(1.24, 0.24, 1.06), "9a9b8d")
	for side in [-1, 1]:
		props.add("trim", bowl + Vector3(side * 0.55, 0.27, 0), Vector3(0.19, 0.30, 1.04), "9c9d91")
		props.add("trim", bowl + Vector3(0, 0.27, side * 0.45), Vector3(1.18, 0.30, 0.20), "adab9a")
	var pool := PlaneMesh.new()
	pool.size = Vector2(0.94, 0.73)
	water_mesh(pool, bowl + Vector3.UP * 0.29, Vector3.ZERO, 0.58)
	props.beam(Vector3(-0.22, 1.68, 0.43), Vector3(-0.22, 0.61, 0.92), 0.13, "697675", "drum")
	props.beam(Vector3(-0.22, 0.61, 0.92), Vector3(-0.22, 0.61, 1.22), 0.13, "6d8389", "drum")
	var drop := QuadMesh.new()
	drop.size = Vector2(0.10, 0.37)
	water_mesh(drop, Vector3(-0.22, 0.45, 1.23), Vector3(0.12, 0, 0), 1.96)

func barrel(pos: Vector3, tint: String, size: float) -> void:
	props.add("drum", pos + Vector3.UP * size * 0.43, Vector3(0.83, 0.86, 0.83) * size, tint)
	for y in [0.13, 0.66, 0.83]:
		props.add("drum", pos + Vector3.UP * size * y, Vector3(0.88, 0.076, 0.88) * size, "697a79")

func starter_garden() -> void:
	props.add("soil", Vector3(0, 0.07, 0), Vector3(3.85, 0.15, 2.59), "6e5140")
	for row in range(4):
		var strip := Vector3(-1.29 + row * 0.86, 0.124, 0)
		props.add("soil", strip, Vector3(0.68, 0.145, 2.38), "896248" if row % 2 == 0 else "75543b")
		for column in range(6):
			var pos := strip + Vector3(sin(column * 2.2 + row) * 0.11, 0.067, -0.99 + column * 0.4)
			crop(pos, 0, row + column)
	for x in [-2.02, 2.02]:
		for z in [-1.38, 0.0, 1.38]:
			props.timber(Vector3(x, 0.35, z), Vector3(0.148, 0.70, 0.15), "8c603c")
	for y in [0.21, 0.49]:
		for z in [-1.38, 1.38]:
			props.beam(Vector3(-2.02, y, z), Vector3(2.02, y, z), 0.088, "ba8d5b", "wood")
		for x in [-2.02, 2.02]:
			props.beam(Vector3(x, y, -1.38), Vector3(x, y, 1.38), 0.075, "a27752", "wood")
	seed_box(Vector3(1.80, 0, 1.76), 0.62, "db8a48")

func worksite() -> void:
	props.add("concrete", Vector3(0, 0.12, 0), Vector3(4.84, 0.24, 3.49), "b0a293")
	props.add("trim", Vector3(0, 0.25, 0), Vector3(4.55, 0.11, 3.13), "8e7663")
	for index in range(7):
		var x := -2.08 + index * 0.69
		for side in [-1, 1]:
			if side > 0 and index in [2, 3, 4]:
				continue
			props.add("concrete", Vector3(x, 0.43, side * 1.46), Vector3(0.67, 0.39, 0.37), "9a9c92" if index % 2 == 0 else "b1b0a4")
	for side in [-1, 1]:
		for index in range(4):
			props.add("concrete", Vector3(side * 2.13, 0.44, -1.06 + index * 0.70), Vector3(0.42, 0.38, 0.66), "9ba09b")
	for post: Vector2 in [Vector2(-1.62, -1.08), Vector2(1.60, -1.08), Vector2(-1.62, 1.05), Vector2(1.60, 1.05)]:
		props.add("trim", Vector3(post.x, 0.29, post.y), Vector3(0.53, 0.27, 0.50), "989a93")
		props.timber(Vector3(post.x, 1.05, post.y), Vector3(0.225, 1.71, 0.24), "ad7750")
	props.beam(Vector3(-1.76, 1.91, -1.08), Vector3(1.75, 1.91, -1.08), 0.19, "b48358", "wood")
	props.beam(Vector3(-1.62, 1.91, -1.17), Vector3(-1.62, 1.91, 1.16), 0.19, "b78050", "wood")
	props.beam(Vector3(1.60, 0.93, -1.16), Vector3(1.60, 0.93, 1.15), 0.15, "8e623f", "wood")
	props.beam(Vector3(-1.61, 0.44, -1.09), Vector3(-0.26, 1.89, -1.09), 0.093, "c89b67", "wood")
	props.timber(Vector3(0.06, 0.68, 1.63), Vector3(1.10, 0.23, 0.11), "594b42")
	for index in range(4):
		props.add("trim", Vector3(-0.33 + index * 0.26, 0.68, 1.697), Vector3(0.09, 0.24, 0.026), "d5aa57", Vector3(0, 0, 0.49))
	for index in range(6):
		var start := Vector3(-1.77, 0.15 + floorf(index / 3.0) * 0.19, 2.11 + (index % 3) * 0.19)
		props.beam(start, start + Vector3(1.07, 0, 0.06), 0.21, "845a38", "drum")
		props.add("ball", start - Vector3(0.01, 0, 0), Vector3(0.056, 0.19, 0.18), "c39b66")
