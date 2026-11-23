extends Node3D

const Economy = preload("res://game/economy.gd")
const CampWorld = preload("res://game/camp_world.gd")
const CampHud = preload("res://game/camp_hud.gd")
const Starter = preload("res://game/starter_camp.gd")
const Construction = preload("res://game/construction.gd")
const Grid = preload("res://game/camp_grid.gd")
const BuildView = preload("res://game/build_view.gd")

const TICK_SECONDS := 1.0
@export var developed_art := false
var economy := Economy.new()
var construction := Construction.new(economy)
var world := CampWorld.new()
var elapsed := 0.0
var camera: Camera3D
var hud: CampHud
var build_view: BuildView
var selected_kind := ""
var selected_cell := Grid.NONE
var placement_issue := ""
const START_FOCUS := Vector3(0, 0, 0.15)
const START_ZOOM := 20.0
var focus := START_FOCUS
var pointers: Dictionary = {}
var touch_starts: Dictionary = {}
var dragging := false
var mouse_start := Vector2.ZERO
var mouse_button := MOUSE_BUTTON_NONE

func _ready() -> void:
	add_child(world)
	world.populate(economy.people, developed_art)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = START_ZOOM
	camera.current = true
	add_child(camera)
	update_camera()
	hud = CampHud.new()
	add_child(hud)
	hud.configure(economy, not developed_art, construction)
	hud.reset_view.connect(reset_camera)
	hud.build_visibility_changed.connect(build_visibility)
	hud.build_panel.kind_selected.connect(select_building)
	hud.build_panel.confirmed.connect(confirm_building)
	hud.build_panel.site_cancelled.connect(cancel_building)
	hud.build_panel.preview_cancelled.connect(cancel_preview)
	build_view = BuildView.new()
	add_child(build_view)
	build_view.configure(construction, world)
	construction.changed.connect(sync_worker_paths)
	economy.job_changed.connect(on_job_changed)
	sync_worker_paths()

func _process(delta: float) -> void:
	elapsed += delta
	while elapsed >= TICK_SECONDS:
		elapsed -= TICK_SECONDS
		economy.advance(TICK_SECONDS)
	var at_site := builder_on_site()
	construction.advance(delta, at_site)
	if hud.build_panel.visible:
		refresh_build_panel(at_site)
	if not developed_art and is_instance_valid(hud):
		var anchor := Starter.SITE + Vector3(0.12, 2.05, 0.10)
		var progress := -1.0
		if not construction.active.is_empty():
			anchor = construction.grid.center_of(construction.active["rect"]) + Vector3.UP * 1.24
			progress = construction.progress()
		hud.place_site_marker(camera.unproject_position(anchor), get_viewport().get_visible_rect(), progress)

func on_job_changed(_person: int, _job: String) -> void:
	sync_worker_paths()

func sync_worker_paths() -> void:
	for index in range(economy.people.size()):
		var job: String = economy.people[index]["job"]
		world.assign_job(index, job)
		var target := world.work_target(index, job)
		if job == "builder" and not construction.active.is_empty():
			target = construction.builder_target()
		elif job == "farmer":
			target = construction.farm_target(index)
		world.set_walking_path(index, construction.grid.route(world.workers[index].position, target))

func builder_on_site() -> bool:
	var builder := construction.worker_id()
	if builder < 0 or construction.active.is_empty():
		return false
	return world.workers[builder].position.distance_squared_to(construction.builder_target()) < 0.045

func build_visibility(open: bool) -> void:
	if open:
		refresh_build_panel(builder_on_site())
	else:
		clear_selection()

func select_building(kind: String) -> void:
	if not construction.catalog.has(kind) or not construction.active.is_empty():
		return
	selected_kind = kind
	selected_cell = construction.suggested_cell(kind)
	hud.build_panel.notify("")
	update_preview()

func select_plot(screen_position: Vector2) -> void:
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen_position),
		camera.project_ray_normal(screen_position))
	if hit != null:
		var size := construction.footprint(selected_kind, Vector2i.ZERO).size
		selected_cell = construction.grid.cell_at(hit) - Vector2i(floori(size.x * 0.5), floori(size.y * 0.5))
		update_preview()

func update_preview() -> void:
	placement_issue = construction.grid.placement_error(construction.footprint(selected_kind, selected_cell))
	build_view.preview(selected_kind, selected_cell, preview_issue().is_empty())
	refresh_build_panel(builder_on_site())

func preview_issue() -> String:
	if selected_kind.is_empty():
		return ""
	if not placement_issue.is_empty():
		return placement_issue
	return "" if economy.can_afford(construction.cost_for(selected_kind)) else "چوب یا سنگ کافی نیست"

func confirm_building() -> void:
	if not hud.build_panel.visible or selected_kind.is_empty():
		return
	var error := construction.begin(selected_kind, selected_cell)
	if error.is_empty():
		clear_selection()
		hud.build_panel.notify("هزینه پرداخت شد")
	else:
		hud.build_panel.notify(error)
	refresh_build_panel(builder_on_site())

func cancel_building() -> void:
	if construction.cancel():
		clear_selection()
		hud.build_panel.notify("ساخت لغو شد و بخشی از مواد برگشت")
		refresh_build_panel(false)

func cancel_preview() -> void:
	clear_selection()
	hud.build_panel.notify("")
	refresh_build_panel(false)

func clear_selection() -> void:
	selected_kind = ""
	selected_cell = Grid.NONE
	placement_issue = ""
	build_view.clear_preview()

func refresh_build_panel(at_site: bool) -> void:
	var status := ""
	var active := not construction.active.is_empty()
	var progress := construction.progress()
	if active:
		var kind: String = construction.active["kind"]
		var title: String = construction.catalog[kind]["title"]
		if construction.worker_id() < 0:
			status = title + " · منتظر سازنده\nدر People یک نفر را سازنده کن."
		elif not at_site:
			status = title + " · سازنده در راه است"
		else:
			status = "%s · %d%% · %d ثانیه کار باقی‌مانده" % [title, floori(progress * 100),
				ceili(construction.active["duration"] - construction.active["elapsed"])]
	elif not construction.completed.is_empty() and selected_kind.is_empty():
		var latest: Dictionary = construction.completed[-1]
		if hud.build_panel.result.text == "هزینه پرداخت شد":
			hud.build_panel.notify("%s آماده شد" % construction.catalog[latest["kind"]]["title"])
	var issue := preview_issue()
	hud.build_panel.update_status(selected_kind, issue, active, progress, status)
	if not selected_kind.is_empty() and not active:
		build_view.set_valid(issue.is_empty())

func update_camera() -> void:
	camera.position = focus + Vector3(0, 29, 39)
	camera.look_at(focus, Vector3.UP)

func reset_camera() -> void:
	focus = START_FOCUS
	camera.size = START_ZOOM
	update_camera()

func pan(relative: Vector2) -> void:
	var speed := camera.size / get_viewport().get_visible_rect().size.y
	var right := camera.basis.x
	var up := Vector3(camera.basis.y.x, 0, camera.basis.y.z).normalized()
	focus += (-right * relative.x + up * relative.y) * speed
	focus.x = clampf(focus.x, -7, 7)
	focus.z = clampf(focus.z, -6, 7)
	update_camera()

func zoom(factor: float) -> void:
	camera.size = clampf(camera.size * factor, 13, 32)

func select_resident_at(screen_position: Vector2) -> void:
	var nearest := -1
	var nearest_distance := 26.0
	for index in range(world.workers.size()):
		var body_center: Vector3 = world.workers[index].global_position + Vector3.UP * 0.66
		if camera.is_position_behind(body_center):
			continue
		var distance := screen_position.distance_to(camera.unproject_position(body_center))
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	if nearest >= 0:
		hud.show_person(nearest)

func world_tap(screen_position: Vector2) -> void:
	if hud.blocks_world_at(screen_position):
		return
	if not selected_kind.is_empty():
		select_plot(screen_position)
	elif not hud.build_panel.visible:
		select_resident_at(screen_position)

func _input(event: InputEvent) -> void:
	# Releases can land over a HUD button even when the drag began in the world.
	if event is InputEventScreenTouch and not event.pressed:
		if touch_starts.has(event.index) and not event.canceled and event.position.distance_to(touch_starts[event.index]) < 9.0:
			world_tap(event.position)
		pointers.erase(event.index)
		touch_starts.erase(event.index)
	elif event is InputEventMouseButton and not event.pressed:
		if dragging and event.button_index == mouse_button:
			if mouse_button == MOUSE_BUTTON_LEFT and event.position.distance_to(mouse_start) < 8.0:
				world_tap(event.position)
			dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and hud.build_panel.visible:
		if selected_kind.is_empty():
			hud.close_build()
		else:
			cancel_preview()
	elif event is InputEventScreenTouch and event.pressed:
		pointers[event.index] = event.position
		if pointers.size() == 1:
			touch_starts[event.index] = event.position
		else:
			touch_starts.clear()
	elif event is InputEventScreenDrag and pointers.has(event.index):
		var old: Vector2 = pointers[event.index]
		pointers[event.index] = event.position
		if touch_starts.has(event.index) and event.position.distance_to(touch_starts[event.index]) >= 9.0:
			touch_starts.erase(event.index)
		if pointers.size() == 1:
			pan(event.relative)
		elif pointers.size() == 2:
			var other_id: int = pointers.keys()[1] if pointers.keys()[0] == event.index else pointers.keys()[0]
			var other: Vector2 = pointers[other_id]
			var distance: float = event.position.distance_to(other)
			if distance > 12.0:
				zoom(clampf(old.distance_to(other) / distance, 0.85, 1.15))
	elif not OS.has_feature("mobile"):
		if event is InputEventMouseButton and event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP: zoom(0.9)
				MOUSE_BUTTON_WHEEL_DOWN: zoom(1.1)
				MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
					dragging = true
					mouse_start = event.position
					mouse_button = event.button_index
		elif event is InputEventMouseMotion and dragging:
			pan(event.relative)
