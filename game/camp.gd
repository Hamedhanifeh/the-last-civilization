extends Node3D

const Economy = preload("res://game/economy.gd")
const CampWorld = preload("res://game/camp_world.gd")
const CampHud = preload("res://game/camp_hud.gd")
const Starter = preload("res://game/starter_camp.gd")

const TICK_SECONDS := 1.0
@export var developed_art := false
var economy := Economy.new()
var world := CampWorld.new()
var elapsed := 0.0
var camera: Camera3D
var hud: CampHud
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
	economy.job_changed.connect(world.assign_job)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = START_ZOOM
	camera.current = true
	add_child(camera)
	update_camera()
	hud = CampHud.new()
	add_child(hud)
	hud.configure(economy, not developed_art)
	hud.reset_view.connect(reset_camera)

func _process(delta: float) -> void:
	elapsed += delta
	while elapsed >= TICK_SECONDS:
		elapsed -= TICK_SECONDS
		economy.advance(TICK_SECONDS)
	if not developed_art and is_instance_valid(hud):
		var anchor := Starter.SITE + Vector3(0.12, 2.05, 0.10)
		hud.place_site_marker(camera.unproject_position(anchor), get_viewport().get_visible_rect())

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

func _input(event: InputEvent) -> void:
	# Releases can land over a HUD button even when the drag began in the world.
	if event is InputEventScreenTouch and not event.pressed:
		if touch_starts.has(event.index) and not event.canceled and event.position.distance_to(touch_starts[event.index]) < 9.0:
			select_resident_at(event.position)
		pointers.erase(event.index)
		touch_starts.erase(event.index)
	elif event is InputEventMouseButton and not event.pressed:
		if dragging and event.button_index == mouse_button:
			if mouse_button == MOUSE_BUTTON_LEFT and event.position.distance_to(mouse_start) < 8.0:
				select_resident_at(event.position)
			dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
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
