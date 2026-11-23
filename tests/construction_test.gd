extends SceneTree

const Economy = preload("res://game/economy.gd")
const Construction = preload("res://game/construction.gd")
const Grid = preload("res://game/camp_grid.gd")

var failures := 0

func _initialize() -> void:
	var economy := Economy.new()
	var construction := Construction.new(economy)
	check(not economy.assign_job(0, "farmer"), "farm required")
	check(not construction.begin("farm", Vector2i(-2, -2)).is_empty(), "outside rejected")
	var tent := construction.grid.cell_at(Vector3(-5.77, 0, -3.54))
	check(not construction.begin("farm", tent).is_empty(), "existing tent rejected")
	check(not construction.begin("tent", construction.grid.cell_at(Vector3(-3.45, 0, 2.61))).is_empty(), "existing tree rejected")
	check(not construction.begin("tent", construction.grid.cell_at(Grid.HUB)).is_empty(), "reserved road rejected")
	check(economy.levels["wood"] == 40 and economy.levels["stone"] == 25, "invalid commands do not charge")
	var cell := construction.suggested_cell("farm")
	check(cell != Grid.NONE, "farm placement exists")
	check(construction.begin("farm", cell).is_empty(), "farm starts")
	check(economy.levels["wood"] == 20 and economy.levels["stone"] == 15, "exact farm cost")
	check(not construction.begin("farm", cell).is_empty() and economy.levels["wood"] == 20, "duplicate does not charge")
	check(construction.worker_id() == 4, "idle builder picked")
	construction.advance(60.0, false)
	check(construction.progress() == 0.0, "no progress during travel")
	construction.advance(19.0, true)
	check(is_equal_approx(construction.progress(), 0.95), "progress tracks on-site work")
	construction.advance(1.0, true)
	check(construction.completed.size() == 1 and construction.active.is_empty(), "farm finishes at twenty seconds")
	check(economy.people[4]["job"] == "idle", "automatic worker released")
	check(not construction.begin("farm", cell).is_empty(), "filled cells stay occupied")
	var food_before: float = economy.rates()["food"]
	check(economy.assign_job(4, "farmer") and economy.assign_job(5, "farmer"), "two farming jobs")
	check(not economy.assign_job(0, "farmer"), "third farmer rejected")
	check(is_equal_approx(economy.rates()["food"] - food_before, 11.0), "5.5 gross food each")
	var food_stock: float = economy.levels["food"]
	economy.advance(60.0)
	check(is_equal_approx(economy.levels["food"] - food_stock, food_before + 11.0), "farmer yield reaches stock after one minute")
	var broke := Economy.new()
	var broke_construction := Construction.new(broke)
	broke.levels["wood"] = 19.0
	var broke_cell := broke_construction.suggested_cell("farm")
	check(not broke_construction.begin("farm", broke_cell).is_empty() and broke.levels["stone"] == 25.0,
		"missing one resource never debits another")
	var cancel_model := Economy.new()
	var cancel_construction := Construction.new(cancel_model)
	for person in range(6):
		cancel_model.assign_job(person, "woodcutter")
	var tent_cell := cancel_construction.suggested_cell("tent")
	check(cancel_construction.begin("tent", tent_cell).is_empty(), "site can await a builder")
	cancel_construction.advance(90.0, true)
	check(cancel_construction.progress() == 0.0, "no work without a builder")
	check(cancel_construction.cancel() and not cancel_construction.cancel(), "refund only once")
	check(is_equal_approx(cancel_model.levels["wood"], 36.4) and is_equal_approx(cancel_model.levels["stone"], 23.8), "80 percent refund")
	check(cancel_construction.begin("tent", tent_cell).is_empty(), "canceled ground is free")
	check(cancel_model.assign_job(5, "builder"), "manual builder assignment")
	cancel_construction.advance(30.0, true)
	check(cancel_construction.housing == 9, "tent adds three spaces")
	print("Construction: %d failure(s)" % failures)
	quit(1 if failures else 0)

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr(description)
