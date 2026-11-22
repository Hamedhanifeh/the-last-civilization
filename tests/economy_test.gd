extends SceneTree

const Economy = preload("res://game/economy.gd")
var failures := 0

func _initialize() -> void:
	var economy := Economy.new()
	check(economy.people.size() == 6, "six residents")
	amounts(economy, [40.0, 25.0, 30.0, 30.0])
	for index in range(300):
		economy.advance(1.0)
	amounts(economy, [60.0, 35.0, 37.5, 36.0])
	check(economy.assign_job(0, "stone_gatherer"), "valid reassignment")
	check(not economy.assign_job(-1, "idle"), "invalid resident rejected")
	check(not economy.assign_job(0, "farmer"), "future job rejected")
	for index in range(60):
		economy.advance(1.0)
	amounts(economy, [60.0, 39.0, 39.0, 37.2])
	check(economy.people[0]["job"] == "stone_gatherer", "one active job")
	var stressed := Economy.new()
	for index in range(6):
		stressed.assign_job(index, "woodcutter")
	for index in range(5000):
		stressed.advance(1.0)
	amounts(stressed, [100.0, 25.0, 0.0, 0.0])
	check(stressed.shortage_count() == 2, "two shortages reported")
	check(stressed.rates()["wood"] == 12.0, "shortage reduces production")
	stressed.assign_job(0, "water_carrier")
	stressed.assign_job(1, "water_carrier")
	stressed.advance(1.0)
	check(stressed.levels["water"] > 0.0 and stressed.shortage_count() == 1, "extra worker clears water shortage")
	print("Economy: %d failure(s)" % failures)
	quit(1 if failures else 0)

func amounts(economy: Economy, expected: Array) -> void:
	for index in range(Economy.RESOURCES.size()):
		var resource: String = Economy.RESOURCES[index]
		var actual: float = economy.levels[resource]
		check(is_equal_approx(actual, expected[index]), "%s: %s expected %s" % [resource, actual, expected[index]])

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr(label)
