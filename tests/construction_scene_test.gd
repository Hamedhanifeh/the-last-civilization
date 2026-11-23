extends SceneTree

const Camp = preload("res://scenes/camp.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("verify_scene")

func verify_scene() -> void:
	var camp = Camp.instantiate()
	root.add_child(camp)
	camp.set_process(false)
	camp.world.set_process(false)
	var hud = camp.hud
	var construction = camp.construction
	hud.show_build_site()
	hud.build_panel.choices["farm"].pressed.emit()
	await process_frame
	var recommended: Vector2i = camp.selected_cell
	check(hud.build_panel.visible and camp.build_view.pad.visible and not hud.build_panel.choose.disabled, "green suggested ground")
	check(camp.economy.levels["wood"] == 40.0, "preview is free")
	var confirm_point: Vector2 = hud.build_panel.choose.get_global_rect().get_center()
	camp.world_tap(confirm_point)
	check(camp.selected_cell == recommended, "HUD blocks world placement")
	var occupied_point: Vector2 = camp.camera.unproject_position(Vector3(-5.77, 0, -3.54))
	camp.world_tap(occupied_point)
	check(hud.build_panel.choose.disabled and camp.build_view.paint.albedo_color.r > 0.8, "occupied ground previews red")
	hud.build_panel.choose.pressed.emit()
	check(construction.active.is_empty() and camp.economy.levels["wood"] == 40.0, "invalid confirm never charges")
	hud.build_panel.cancel_preview.pressed.emit()
	check(not camp.build_view.pad.visible and camp.economy.levels["wood"] == 40.0, "preview cancel is free")
	hud.build_panel.choices["farm"].pressed.emit()
	await capture("step-02-placement.png")
	hud.build_panel.choose.pressed.emit()
	check(construction.worker_id() == 4 and not camp.builder_on_site(), "builder starts outside site on a route")
	check(camp.economy.levels["wood"] == 20.0 and camp.economy.levels["stone"] == 15.0, "normal UI charges exact cost")
	var elapsed := 0.0
	var arrival_time := -1.0
	for tick in range(1800):
		camp.world._process(1.0 / 30.0)
		camp._process(1.0 / 30.0)
		elapsed += 1.0 / 30.0
		if arrival_time < 0.0 and construction.progress() > 0.0:
			arrival_time = elapsed
		if construction.active.is_empty():
			break
	check(arrival_time > 0.1 and elapsed - arrival_time >= 19.95, "construction waits for actual movement then twenty seconds of work")
	check(construction.completed.size() == 1 and camp.build_view.finished_count == 1, "actual farm model replaces the site")
	hud.close_build()
	hud.show_person(4)
	check(not hud.job_buttons["farmer"].disabled, "farm unlocks the farmer button")
	var old_rate: float = camp.economy.rates()["food"]
	hud.job_buttons["farmer"].pressed.emit()
	check(is_equal_approx(camp.economy.rates()["food"] - old_rate, 5.5), "visible role raises food by 5.5/minute")
	hud.toggle_people()
	await capture("step-02-farm.png")
	print("Construction scene: %d failure(s)" % failures)
	quit(1 if failures else 0)

func capture(filename: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png("res://builds/" + filename) == OK, "Windows screenshot saved")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr(description)
