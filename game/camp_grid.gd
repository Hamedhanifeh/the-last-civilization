extends RefCounted

const TILE := 1.4
const AREA := Rect2i(0, 0, 20, 14)
const ORIGIN := Vector2(-14, -9.8)
const HUB := Vector3(0.15, 0, 2.15)
const NONE := Vector2i(-999, -999)
const OUTLINE := [Vector2(-14.2, -1.4), Vector2(-11.8, -6.2), Vector2(-5.8, -10.3),
	Vector2(1.6, -10.4), Vector2(9.7, -7.1), Vector2(13.8, -2.1), Vector2(13.8, 2.2),
	Vector2(10.4, 5.9), Vector2(4.2, 8.8), Vector2(-3.4, 9.2), Vector2(-10.7, 6.5), Vector2(-14.2, 3.0)]
const STRUCTURES := [Rect2(-7.7, -5.13, 3.6, 3.23), Rect2(-2.7, -7.95, 3.75, 3.46),
	Rect2(3.0, -4.9, 2.25, 2.50), Rect2(-1.01, -0.75, 2.01, 2.08),
	Rect2(-10.7, 2.38, 3.37, 3.14), Rect2(-3.4, 4.45, 4.81, 3.53),
	Rect2(4.64, -3.06, 5.76, 4.91), Rect2(2.72, 2.27, 2.11, 1.56)]
const TREES := [Vector2(-10.1, -1.7), Vector2(-5.1, -7.10), Vector2(-3.45, 2.61), Vector2(5.25, -6.90), Vector2(-11.12, 1.15)]
const ROAD_ENDS := [Vector3(-7.05, 0, 4.55), Vector3(7.25, 0, 6.85), Vector3(6.38, 0, 1.72),
	Vector3(-3.9, 0, -2.15), Vector3(2.75, 0, -4.4)]
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var navigation := AStarGrid2D.new()
var allowed: Dictionary = {}
var reserved: Dictionary = {}
var occupied: Dictionary = {}

func _init() -> void:
	navigation.region = AREA
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	var polygon := PackedVector2Array(OUTLINE)
	for z in range(AREA.size.y):
		for x in range(AREA.size.x):
			var cell := Vector2i(x, z)
			var center := world_at(cell)
			var p := Vector2(center.x, center.z)
			var inside := Geometry2D.is_point_in_polygon(p, polygon)
			var walkable := inside
			var placeable := inside
			var square := Rect2(p - Vector2.ONE * TILE * 0.5, Vector2.ONE * TILE)
			for bound: Rect2 in STRUCTURES:
				walkable = walkable and not bound.has_point(p)
				placeable = placeable and not bound.intersects(square)
			for tree: Vector2 in TREES:
				placeable = placeable and not square.grow(0.55).has_point(tree)
			if inside:
				for corner: Vector2 in [square.position, square.end, Vector2(square.position.x, square.end.y), Vector2(square.end.x, square.position.y)]:
					placeable = placeable and Geometry2D.is_point_in_polygon(corner, polygon)
			for finish: Vector3 in ROAD_ENDS:
				if center.distance_to(Geometry3D.get_closest_point_to_segment(center, HUB, finish)) < 1.02:
					reserved[cell] = true
			if placeable:
				allowed[cell] = true
			navigation.set_point_solid(cell, not walkable)

func cell_at(pos: Vector3) -> Vector2i:
	var position := (Vector2(pos.x, pos.z) - ORIGIN) / TILE
	return Vector2i(floori(position.x), floori(position.y))

func world_at(cell: Vector2i) -> Vector3:
	var position := ORIGIN + (Vector2(cell) + Vector2.ONE * 0.5) * TILE
	return Vector3(position.x, 0, position.y)

func center_of(rect: Rect2i) -> Vector3:
	return world_at(rect.position) + Vector3(rect.size.x - 1, 0, rect.size.y - 1) * TILE * 0.5

func placement_error(rect: Rect2i) -> String:
	if not AREA.encloses(rect):
		return "بیرون محدوده کمپ"
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, z)
			if occupied.has(cell) or not allowed.has(cell):
				return "زمین اشغال است یا برای ساخت مناسب نیست"
			if reserved.has(cell):
				return "مسیر عبور بازمانده‌ها باید باز بماند"
	set_occupied(rect, true)
	var connected := approach(rect) != NONE
	set_occupied(rect, false)
	if not connected:
		return "جای کار برای سازنده وجود ندارد"
	return ""

func set_occupied(rect: Rect2i, value: bool) -> void:
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, z)
			if value:
				occupied[cell] = true
			else:
				occupied.erase(cell)
			navigation.set_point_solid(cell, value)

func is_open(cell: Vector2i) -> bool:
	return AREA.has_point(cell) and not navigation.is_point_solid(cell)

func closest_open(cell: Vector2i) -> Vector2i:
	if is_open(cell):
		return cell
	for radius in range(1, 9):
		for z in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, z)
				if is_open(candidate):
					return candidate
	return NONE

func approach(rect: Rect2i) -> Vector2i:
	var best := NONE
	var shortest := INF
	var start := closest_open(cell_at(HUB))
	if start == NONE:
		return best
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			for direction: Vector2i in DIRECTIONS:
				var candidate := Vector2i(x, z) + direction
				if rect.has_point(candidate) or not is_open(candidate):
					continue
				var route := navigation.get_id_path(start, candidate)
				if not route.is_empty() and route.size() < shortest:
					best = candidate
					shortest = route.size()
	return best

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var path := PackedVector3Array()
	var start := closest_open(cell_at(from))
	var finish := closest_open(cell_at(to))
	if start == NONE or finish == NONE:
		return path
	var route_cells := navigation.get_id_path(start, finish)
	for index in range(route_cells.size()):
		if index == 0 and is_open(cell_at(from)):
			continue
		path.append(world_at(route_cells[index]))
	if not route_cells.is_empty() and cell_at(to) == finish:
		path.append(Vector3(to.x, 0, to.z))
	return path
