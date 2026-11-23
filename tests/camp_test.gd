extends SceneTree

const Camp = preload("res://scenes/camp.tscn")
const Hud = preload("res://game/camp_hud.gd")

func _initialize() -> void:
	call_deferred("verify_scene")

func verify_scene() -> void:
	var camp = Camp.instantiate()
	root.add_child(camp)
	var hud: Hud = camp.get_child(2)
	var starter_scene_ready: bool = camp.world.has_node("StarterSettlement") and hud.site_marker != null \
		and hud.assignment_goal.text == "Build a Workshop (0/1)"
	var initial_target: Vector3 = camp.world.destinations[0]
	hud.people_toggle.pressed.emit()
	hud.rows[0].pressed.emit()
	hud.job_buttons["stone_gatherer"].pressed.emit()
	var net: Dictionary = camp.economy.rates()
	hud.toggle_resource("stone")
	var resource_drawer_open: bool = hud.rate_values["stone"].visible and not hud.rate_values["wood"].visible
	camp.pan(Vector2(120, 30))
	camp.zoom(0.7)
	hud.reset_view.emit()
	var resident_screen: Vector2 = camp.camera.unproject_position(camp.world.workers[2].global_position + Vector3.UP * 0.66)
	camp.select_resident_at(resident_screen)
	var passed: bool = starter_scene_ready and camp.world.workers.size() == 6 and hud.panel.visible \
		and camp.world.destinations[0] != initial_target \
		and camp.economy.people[0]["job"] == "stone_gatherer" \
		and net["wood"] == 0.0 and net["stone"] == 4.0 \
		and str(hud.rate_values["stone"].text).contains("+4.0") \
		and resource_drawer_open and hud.has_assigned_job \
		and camp.focus == camp.START_FOCUS and camp.camera.size == camp.START_ZOOM \
		and hud.selected == 2 and camp.world.tools[0]["stone_gatherer"].visible \
		and not camp.world.tools[0]["woodcutter"].visible
	print("Camp integration: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
