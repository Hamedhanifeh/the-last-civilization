extends RefCounted

const Economy = preload("res://game/economy.gd")
const Grid = preload("res://game/camp_grid.gd")
const REFUND_RATIO := 0.8

signal changed

var economy: Economy
var grid := Grid.new()
var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
var active: Dictionary = {}
var completed: Array[Dictionary] = []
var housing := 6
var next_id := 1

func _init(model: Economy) -> void:
	economy = model

func footprint(kind: String, start: Vector2i) -> Rect2i:
	var dimensions: Array = catalog[kind]["size"]
	return Rect2i(start, Vector2i(int(dimensions[0]), int(dimensions[1])))

func cost_for(kind: String) -> Dictionary:
	return {"wood": catalog[kind]["wood"], "stone": catalog[kind]["stone"]}

func error_for(kind: String, start: Vector2i) -> String:
	if not catalog.has(kind):
		return "سازه را انتخاب کن"
	if not active.is_empty():
		return "ابتدا ساخت فعلی را تمام یا لغو کن"
	var error := grid.placement_error(footprint(kind, start))
	if not error.is_empty():
		return error
	if not economy.can_afford(cost_for(kind)):
		return "چوب یا سنگ کافی نیست"
	return ""

func suggested_cell(kind: String) -> Vector2i:
	var best := Grid.NONE
	var closest := INF
	var target := Vector3(-4.4, 0, 3.0) if kind == "farm" else Vector3(-7.5, 0, -5.7)
	for z in range(Grid.AREA.size.y):
		for x in range(Grid.AREA.size.x):
			var cell := Vector2i(x, z)
			var rect := footprint(kind, cell)
			var distance := grid.center_of(rect).distance_squared_to(target)
			if distance < closest and grid.placement_error(rect).is_empty():
				best = cell
				closest = distance
	return best

func begin(kind: String, start: Vector2i) -> String:
	var error := error_for(kind, start)
	if not error.is_empty():
		return error
	var rect := footprint(kind, start)
	grid.set_occupied(rect, true)
	var work_cell := grid.approach(rect)
	if work_cell == Grid.NONE:
		grid.set_occupied(rect, false)
		return "هیچ مسیر قابل عبوری به محل ساخت نیست"
	var cost := cost_for(kind)
	active = {"id": next_id, "kind": kind, "rect": rect, "cost": cost,
		"elapsed": 0.0, "duration": float(catalog[kind]["seconds"]), "approach": work_cell,
		"auto_builder": -1}
	if not economy.spend(cost):
		active = {}
		grid.set_occupied(rect, false)
		return "چوب یا سنگ کافی نیست"
	next_id += 1
	var available := economy.workers_in("idle")
	if worker_id() < 0 and not available.is_empty():
		active["auto_builder"] = available[0]
		economy.assign_job(available[0], "builder")
	changed.emit()
	return ""

func worker_id() -> int:
	var builders := economy.workers_in("builder")
	return -1 if builders.is_empty() else builders[0]

func builder_target() -> Vector3:
	return grid.world_at(active["approach"])

func progress() -> float:
	return 0.0 if active.is_empty() else clampf(float(active["elapsed"]) / active["duration"], 0.0, 1.0)

func advance(seconds: float, at_worksite: bool) -> void:
	if active.is_empty() or worker_id() < 0 or not at_worksite or seconds <= 0:
		return
	active["elapsed"] = minf(float(active["elapsed"]) + seconds, active["duration"])
	if progress() < 1.0:
		return
	var finished := active
	active = {}
	completed.append(finished)
	var definition: Dictionary = catalog[finished["kind"]]
	housing += int(definition["housing"])
	var capacity := int(economy.settings["jobs"]["farmer"]["capacity"])
	economy.set_farmer_capacity(capacity + int(definition["farmer_slots"]))
	release_auto_builder(finished)
	changed.emit()

func cancel() -> bool:
	if active.is_empty():
		return false
	var removed := active
	active = {}
	grid.set_occupied(removed["rect"], false)
	economy.refund(removed["cost"], REFUND_RATIO)
	release_auto_builder(removed)
	changed.emit()
	return true

func release_auto_builder(site: Dictionary) -> void:
	var person: int = site["auto_builder"]
	if person >= 0 and economy.people[person]["job"] == "builder":
		economy.assign_job(person, "idle")

func farm_target(person: int) -> Vector3:
	var ordinal := economy.workers_in("farmer").find(person)
	for building in completed:
		var capacity: int = catalog[building["kind"]]["farmer_slots"]
		if capacity > 0 and ordinal >= 0 and ordinal < capacity:
			var target := grid.world_at(building["approach"])
			return target + Vector3(-0.22 + ordinal * 0.43, 0, 0)
		ordinal -= capacity
	return Grid.HUB
