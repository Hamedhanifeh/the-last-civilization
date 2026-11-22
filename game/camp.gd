extends Node3D

const Economy = preload("res://game/economy.gd")
const CampWorld = preload("res://game/camp_world.gd")
const CampHud = preload("res://game/camp_hud.gd")

const TICK_SECONDS := 1.0
var economy := Economy.new()
var world := CampWorld.new()
var elapsed := 0.0
var camera: Camera3D
var focus := Vector3(0, 0, 0.5)
var pointers: Dictionary = {}
var dragging := false

func _ready() -> void:
	add_child(world)
	world.populate(economy.people)
	economy.job_changed.connect(world.assign_job)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22.0
	camera.current = true
	add_child(camera)
	update_camera()
	var hud := CampHud.new()
	add_child(hud)
	hud.configure(economy)

func _process(delta: float) -> void:
	elapsed += delta
	while elapsed >= TICK_SECONDS:
		elapsed -= TICK_SECONDS
		economy.advance(TICK_SECONDS)

func update_camera() -> void:
	camera.position = focus + Vector3(24, 24, 28)
	camera.look_at(focus, Vector3.UP)

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

func _input(event: InputEvent) -> void:
	# Releases can land over a HUD button even when the drag began in the world.
	if event is InputEventScreenTouch and not event.pressed:
		pointers.erase(event.index)
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		pointers[event.index] = event.position
	elif event is InputEventScreenDrag and pointers.has(event.index):
		var old: Vector2 = pointers[event.index]
		pointers[event.index] = event.position
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
				MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT: dragging = true
		elif event is InputEventMouseMotion and dragging:
			pan(event.relative)
