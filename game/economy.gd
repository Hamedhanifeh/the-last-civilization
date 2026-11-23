extends RefCounted

signal changed
signal job_changed(person: int, job: String)

const RESOURCES := ["wood", "stone", "food", "water"]

var settings: Dictionary
var levels: Dictionary
var people: Array

func _init() -> void:
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	levels = settings["initial"].duplicate()
	people = settings["people"].duplicate(true)

func assign_job(person: int, job: String) -> bool:
	if not can_assign_job(person, job):
		return false
	if people[person]["job"] != job:
		people[person]["job"] = job
		job_changed.emit(person, job)
		changed.emit()
	return true

func can_assign_job(person: int, job: String) -> bool:
	if person < 0 or person >= people.size() or not settings["jobs"].has(job):
		return false
	if people[person]["job"] == job:
		return true
	var definition: Dictionary = settings["jobs"][job]
	return not definition.has("capacity") or workers_in(job).size() < int(definition["capacity"])

func workers_in(job: String) -> Array[int]:
	var result: Array[int] = []
	for index in range(people.size()):
		if people[index]["job"] == job:
			result.append(index)
	return result

func set_farmer_capacity(capacity: int) -> void:
	settings["jobs"]["farmer"]["capacity"] = capacity
	changed.emit()

func can_afford(cost: Dictionary) -> bool:
	for resource: String in cost:
		if not levels.has(resource) or cost[resource] < 0.0 or levels[resource] < cost[resource]:
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for resource: String in cost:
		levels[resource] -= cost[resource]
	changed.emit()
	return true

func refund(cost: Dictionary, ratio: float) -> void:
	for resource: String in cost:
		levels[resource] = minf(levels[resource] + cost[resource] * ratio, settings["capacity"][resource])
	changed.emit()

func shortage_count() -> int:
	return int(levels["food"] <= 0.0) + int(levels["water"] <= 0.0)

func rates() -> Dictionary:
	var production := {"wood": 0.0, "stone": 0.0, "food": 0.0, "water": 0.0}
	var efficiency := 1.0
	match shortage_count():
		1: efficiency = settings["efficiency_one_shortage"]
		2: efficiency = settings["efficiency_two_shortages"]
	for person: Dictionary in people:
		var job: Dictionary = settings["jobs"][person["job"]]
		if not job["resource"].is_empty():
			production[job["resource"]] += float(job["rate"]) * efficiency
	for resource: String in settings["per_person_use"]:
		production[resource] -= people.size() * float(settings["per_person_use"][resource])
	return production

func advance(seconds: float) -> void:
	var net := rates()
	for resource: String in RESOURCES:
		levels[resource] = clampf(levels[resource] + net[resource] * seconds / 60.0,
			0.0, settings["capacity"][resource])
	changed.emit()
