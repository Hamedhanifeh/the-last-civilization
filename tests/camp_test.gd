extends SceneTree

const Camp = preload("res://scenes/camp.tscn")
const Hud = preload("res://game/camp_hud.gd")

func _initialize() -> void:
	call_deferred("verify_scene")

func verify_scene() -> void:
	var camp = Camp.instantiate()
	root.add_child(camp)
	var hud: Hud = camp.get_child(2)
	var initial_target: Vector3 = camp.world.destinations[0]
	hud.people_toggle.pressed.emit()
	hud.rows[0].pressed.emit()
	hud.job_buttons["stone_gatherer"].pressed.emit()
	var net: Dictionary = camp.economy.rates()
	var passed: bool = camp.world.workers.size() == 6 and hud.panel.visible \
		and camp.world.destinations[0] != initial_target \
		and camp.economy.people[0]["job"] == "stone_gatherer" \
		and net["wood"] == 0.0 and net["stone"] == 4.0 \
		and str(hud.rate_values["stone"].text).contains("+4.0")
	print("Camp integration: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
