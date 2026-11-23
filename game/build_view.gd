extends Node3D

const Grid = preload("res://game/camp_grid.gd")
const Construction = preload("res://game/construction.gd")
const CampWorld = preload("res://game/camp_world.gd")

var model: Construction
var world: CampWorld
var mesh_grid: MeshInstance3D
var pad: MeshInstance3D
var outline: MeshInstance3D
var paint := StandardMaterial3D.new()
var edge := StandardMaterial3D.new()
var active_model: Node3D
var active_id := -1
var finished_count := 0

func configure(construction: Construction, camp_world: CampWorld) -> void:
	model = construction
	world = camp_world
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for key: Vector2i in model.grid.allowed:
		var point := model.grid.world_at(key) + Vector3.UP * 0.027
		var half := Grid.TILE * 0.5
		var points := [point + Vector3(-half, 0, -half), point + Vector3(half, 0, -half),
			point + Vector3(half, 0, half), point + Vector3(-half, 0, half)]
		for side in range(4):
			lines.surface_add_vertex(points[side])
			lines.surface_add_vertex(points[(side + 1) % 4])
	lines.surface_end()
	mesh_grid = mesh_with(lines, material(Color(0.96, 0.88, 0.63, 0.52)))
	paint = material(Color(0.2, 0.9, 0.55, 0.58))
	edge = material(Color(0.49, 0.99, 0.71, 0.92))
	pad = mesh_with(BoxMesh.new(), paint)
	var square := ImmediateMesh.new()
	square.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point: Vector3 in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5),
		Vector3(-0.5, 0, 0.5), Vector3(-0.5, 0, -0.5)]:
		square.surface_add_vertex(point)
	square.surface_end()
	outline = mesh_with(square, edge)
	clear_preview()
	model.changed.connect(sync_sites)

func preview(kind: String, start: Vector2i, valid: bool) -> void:
	mesh_grid.show()
	if start == Grid.NONE:
		pad.hide()
		outline.hide()
		return
	var rect := model.footprint(kind, start)
	var center := model.grid.center_of(rect)
	var span := Vector2(rect.size) * Grid.TILE
	var height := 1.06 if kind == "tent" else 0.38
	if not (pad.mesh is PrismMesh) and kind == "tent":
		pad.mesh = PrismMesh.new()
	elif not (pad.mesh is BoxMesh) and kind != "tent":
		pad.mesh = BoxMesh.new()
	pad.scale = Vector3(span.x - 0.12, height, span.y - 0.12)
	pad.position = center + Vector3.UP * (height * 0.5 + 0.04)
	outline.position = center + Vector3.UP * 0.047
	outline.scale = Vector3(span.x, 1, span.y)
	set_valid(valid)
	pad.show()
	outline.show()

func set_valid(valid: bool) -> void:
	paint.albedo_color = Color(0.18, 0.88, 0.46, 0.52) if valid else Color(0.94, 0.28, 0.22, 0.58)
	edge.albedo_color = Color(0.58, 1.0, 0.74, 1.0) if valid else Color(1.0, 0.38, 0.27, 1.0)

func clear_preview() -> void:
	mesh_grid.hide()
	pad.hide()
	outline.hide()

func sync_sites() -> void:
	var next_id := int(model.active.get("id", -1))
	if active_id != next_id:
		if is_instance_valid(active_model):
			active_model.hide()
			active_model.queue_free()
			active_model = null
		active_id = next_id
		if next_id >= 0:
			active_model = create_site(model.active, false)
	while finished_count < model.completed.size():
		create_site(model.completed[finished_count], true)
		finished_count += 1

func create_site(site: Dictionary, finished: bool) -> Node3D:
	var rect: Rect2i = site["rect"]
	return world.draw_construction(site["kind"], model.grid.center_of(rect), Vector2(rect.size) * Grid.TILE, finished)

func material(color: Color) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.albedo_color = color
	return surface

func mesh_with(mesh: Mesh, surface: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = surface
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	return item
