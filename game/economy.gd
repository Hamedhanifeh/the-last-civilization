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
	if person < 0 or person >= people.size() or not settings["jobs"].has(job):
		return false
	if people[person]["job"] != job:
		people[person]["job"] = job
		job_changed.emit(person, job)
		changed.emit()
	return true

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
