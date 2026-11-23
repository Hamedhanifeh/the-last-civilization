extends CanvasLayer

const Economy = preload("res://game/economy.gd")
signal reset_view

const TITLES := {"wood": "چوب", "stone": "سنگ", "food": "غذا", "water": "آب"}
const RESOURCE_COLORS := {"wood": "edb978", "stone": "bac7d2", "food": "c2d48d", "water": "8bd0d3"}
const JOBS := {
	"woodcutter": "چوب‌بر", "stone_gatherer": "سنگ‌جمع‌کن", "forager": "گردآورنده غذا",
	"water_carrier": "آب‌رسان", "idle": "آزاد",
}

var economy: Economy
var panel: PanelContainer
var resource_values: Dictionary = {}
var rate_values: Dictionary = {}
var rows: Array[Button] = []
var job_buttons: Dictionary = {}
var status: Label
var hint: Label
var people_toggle: Button
var goals: VBoxContainer
var assignment_goal: Label
var food_goal: Label
var roster_goal: Label
var assignment_mark: Label
var food_mark: Label
var roster_mark: Label
var level_track: ProgressBar
var has_assigned_job := false
var info_dialog: AcceptDialog
var site_marker: Button
var site_badge: Panel
var starter_art := true
var selected := 0

func configure(model: Economy, use_starter_art := true) -> void:
	economy = model
	starter_art = use_starter_art
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = make_theme()
	create_header(root)
	create_goals(root)
	create_footer(root)
	create_people_panel(root)
	if starter_art:
		create_site_marker(root)
	info_dialog = AcceptDialog.new()
	info_dialog.title = "The Last Civilization"
	root.add_child(info_dialog)
	economy.changed.connect(refresh)
	economy.job_changed.connect(mark_assignment)
	refresh()

func create_site_marker(root: Control) -> void:
	site_marker = button("  Site")
	site_marker.icon = icon("hammer-light")
	site_marker.expand_icon = true
	site_marker.add_theme_constant_override("icon_max_width", 24)
	site_marker.add_theme_stylebox_override("normal", surface("3f4a3e", "f6ead0", 12))
	site_marker.add_theme_stylebox_override("hover", surface("596755", "f6ead0", 12))
	site_marker.size = Vector2(117, 43)
	site_marker.pressed.connect(show_build_site)
	root.add_child(site_marker)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(49, 41), Vector2(68, 41), Vector2(58, 51)])
	tail.color = Color("f6ead0")
	site_marker.add_child(tail)
	root.move_child(site_marker, 0)

func place_site_marker(point: Vector2, area: Rect2) -> void:
	if site_marker == null:
		return
	site_marker.position = point - Vector2(59, 49)
	site_marker.visible = area.grow(-35).has_point(point) and not panel.visible

func create_header(root: Control) -> void:
	var header := HBoxContainer.new()
	root.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 17
	header.offset_right = -17
	header.offset_top = 8
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_card := card("293e3a")
	header.add_child(title_card)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 9)
	title_card.add_child(identity)
	identity.add_child(picture("emblem", 48))
	var title := VBoxContainer.new()
	identity.add_child(title)
	title.add_theme_constant_override("separation", 0)
	label(title, "Last Civilization", 22, "fff3da")
	var level := HBoxContainer.new()
	title.add_child(level)
	label(level, "Lv. 1", 14, "eed19b")
	level_track = ProgressBar.new()
	level_track.custom_minimum_size = Vector2(89, 9)
	level_track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_track.show_percentage = false
	level_track.add_theme_stylebox_override("background", surface("182a2b", "182a2b", 5))
	level_track.add_theme_stylebox_override("fill", surface("e9b758", "e9b758", 5))
	level.add_child(level_track)
	var population := card("293e3a")
	population.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(population)
	var count := HBoxContainer.new()
	population.add_child(count)
	count.add_child(picture("people", 25))
	label(count, "%d/%d" % [economy.people.size(), 6], 18, "fff3da")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	for resource: String in Economy.RESOURCES:
		var resource_card := card("293e3a")
		var compact := surface("293e3a", "597363", 11)
		compact.content_margin_left = 7
		compact.content_margin_right = 7
		compact.content_margin_top = 4
		compact.content_margin_bottom = 4
		resource_card.add_theme_stylebox_override("panel", compact)
		resource_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(resource_card)
		var column := VBoxContainer.new()
		resource_card.add_child(column)
		column.add_theme_constant_override("separation", 0)
		var line := HBoxContainer.new()
		column.add_child(line)
		line.add_child(picture(resource, 32))
		var amount := label(line, "", 20, "fff3da")
		amount.custom_minimum_size.x = 43
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var color: String = RESOURCE_COLORS[resource]
		resource_values[resource] = amount
		rate_values[resource] = label(column, "", 15, color)
		rate_values[resource].hide()
		var details := button("+")
		details.custom_minimum_size = Vector2(26, 26)
		details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		details.add_theme_stylebox_override("normal", surface("67864d", "94aa64", 5))
		details.pressed.connect(toggle_resource.bind(resource))
		line.add_child(details)
	var settings := button("")
	settings.icon = icon("settings")
	settings.expand_icon = true
	settings.custom_minimum_size = Vector2(51, 49)
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings.pressed.connect(show_camera_help)
	header.add_child(settings)

func create_goals(root: Control) -> void:
	var goals_card := card("344944")
	root.add_child(goals_card)
	goals_card.position = Vector2(14, 86)
	goals_card.custom_minimum_size.x = 245
	var outer := VBoxContainer.new()
	goals_card.add_child(outer)
	var cream := card("f0e7ce")
	var title := "Early Settlement" if starter_art else "Development Goals"
	var heading := button(title + "    ⌃")
	heading.icon = icon("clipboard")
	heading.expand_icon = true
	heading.add_theme_constant_override("icon_max_width", 26)
	heading.flat = true
	heading.alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.pressed.connect(func() -> void:
		cream.visible = not cream.visible
		heading.text = title + ("    ⌃" if cream.visible else "    ⌄")
	)
	outer.add_child(heading)
	outer.add_child(cream)
	goals = VBoxContainer.new()
	cream.add_child(goals)
	var first := goal_row("build" if starter_art else "crate")
	assignment_goal = first[0]
	assignment_mark = first[1]
	goals.add_child(HSeparator.new())
	var second := goal_row("crop")
	food_goal = second[0]
	food_mark = second[1]
	goals.add_child(HSeparator.new())
	var third := goal_row("people")
	roster_goal = third[0]
	roster_mark = third[1]
	status = label(goals, "", 14, "944430")
	status.hide()

func goal_row(asset: String) -> Array[Label]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	goals.add_child(row)
	var glyph := picture(asset, 22)
	if asset == "people":
		glyph.modulate = Color("71925a")
	row.add_child(glyph)
	var text := label(row, "", 15, "3e4634")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mark := label(row, "", 18, "668949")
	mark.custom_minimum_size.x = 18
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return [text, mark]

func create_footer(root: Control) -> void:
	var footer := HBoxContainer.new()
	root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -77
	footer.offset_bottom = -11
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 8)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var build := action("Build", "build")
	build.add_theme_stylebox_override("normal", surface("efbd62", "ffe097", 14))
	build.add_theme_stylebox_override("hover", surface("ffc96e", "ffe097", 14))
	build.add_theme_color_override("font_color", Color("4a3321"))
	build.add_theme_color_override("font_hover_color", Color("4a3321"))
	build.pressed.connect(show_build_site)
	footer.add_child(build)
	if starter_art:
		site_badge = Panel.new()
		site_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		site_badge.size = Vector2(15, 15)
		site_badge.position = Vector2(100, 1)
		var paint := surface("c94f43", "ffe5c2", 8)
		paint.set_border_width_all(2)
		site_badge.add_theme_stylebox_override("panel", paint)
		build.add_child(site_badge)
	people_toggle = action("People", "people")
	people_toggle.pressed.connect(toggle_people)
	footer.add_child(people_toggle)
	var research := action("Research", "research")
	research.disabled = true
	footer.add_child(research)
	var upgrade := action("Upgrade", "upgrade")
	upgrade.disabled = true
	footer.add_child(upgrade)
	var locked := action("", "lock")
	locked.disabled = true
	footer.add_child(locked)

func create_people_panel(root: Control) -> void:
	panel = card("172c2a")
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -368
	panel.offset_right = -24
	panel.offset_top = 111
	panel.visible = false
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	label(content, "بازمانده‌ها", 24, "fff3da")
	for index in range(economy.people.size()):
		var row := button("")
		row.toggle_mode = true
		row.pressed.connect(select_person.bind(index))
		content.add_child(row)
		rows.append(row)
	hint = label(content, "", 17, "d1d9b1")
	var jobs := GridContainer.new()
	jobs.columns = 2
	content.add_child(jobs)
	for job: String in JOBS:
		var option := button(JOBS[job])
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.custom_minimum_size.y = 40
		option.toggle_mode = true
		option.pressed.connect(change_job.bind(job))
		jobs.add_child(option)
		job_buttons[job] = option

func toggle_people() -> void:
	panel.visible = not panel.visible
	people_toggle.text = "Close" if panel.visible else "People"

func toggle_resource(resource: String) -> void:
	for key: String in rate_values:
		rate_values[key].visible = key == resource and not rate_values[key].visible

func mark_assignment(_person: int, _job: String) -> void:
	has_assigned_job = true

func show_build_site() -> void:
	if site_badge != null:
		site_badge.hide()
	info_dialog.dialog_text = "داربست چوبی سمت راست محل کارگاه است. ساخت‌وساز در گام ۲ فعال می‌شود." if starter_art \
		else "این نما کارگاه و انبار توسعه‌یافته را نشان می‌دهد. ساخت‌وساز در گام ۲ فعال می‌شود."
	info_dialog.popup_centered()

func show_camera_help() -> void:
	reset_view.emit()
	info_dialog.dialog_text = "نما به حالت شروع برگشت.\nبرای حرکت، زمینه را بکش. برای زوم، از دو انگشت یا چرخ ماوس استفاده کن."
	info_dialog.popup_centered()

func select_person(index: int) -> void:
	selected = index
	refresh()

func show_person(index: int) -> void:
	if not panel.visible:
		toggle_people()
	select_person(index)

func change_job(job: String) -> void:
	economy.assign_job(selected, job)
	refresh()

func refresh() -> void:
	var net := economy.rates()
	for resource: String in Economy.RESOURCES:
		var rate: float = net[resource]
		resource_values[resource].text = str(floori(economy.levels[resource]))
		rate_values[resource].text = "%+.1f در دقیقه" % rate
		if economy.levels[resource] >= economy.settings["capacity"][resource]:
			rate_values[resource].text = "ظرفیت پر"
		elif rate < 0.0:
			rate_values[resource].modulate = Color("ffc99b")
		else:
			rate_values[resource].modulate = Color.WHITE
	var shortages: Array[String] = []
	for resource in ["food", "water"]:
		if economy.levels[resource] <= 0.0:
			shortages.append(TITLES[resource])
	assignment_goal.text = "Build a Workshop (0/1)" if starter_art else "Assign a Job"
	assignment_mark.text = "✓" if has_assigned_job and not starter_art else "□"
	var gained := clampi(floori(economy.levels["food"] - economy.settings["initial"]["food"]), 0, 10)
	food_goal.text = "Grow Food (%d/10)" % gained
	food_mark.text = "✓" if gained == 10 else "□"
	roster_goal.text = "Have 6 Survivors"
	roster_mark.text = "✓"
	level_track.value = 100.0 * (1 + int(has_assigned_job and not starter_art) + int(gained == 10)) / 3.0
	status.visible = not shortages.is_empty()
	if not shortages.is_empty():
		status.text = "کمبود %s · یک نفر دیگر به برداشت بفرست" % " و ".join(shortages)
	for index in range(rows.size()):
		var person: Dictionary = economy.people[index]
		rows[index].text = "%s   ·   %s" % [person["name"], JOBS[person["job"]]]
		rows[index].set_pressed_no_signal(index == selected)
	hint.text = "شغل %s" % economy.people[selected]["name"]
	for job: String in job_buttons:
		job_buttons[job].set_pressed_no_signal(job == economy.people[selected]["job"])

func make_theme() -> Theme:
	var theme := Theme.new()
	if ResourceLoader.exists("res://assets/Vazirmatn-Regular.ttf"):
		theme.default_font = load("res://assets/Vazirmatn-Regular.ttf")
	theme.default_font_size = 19
	for state in ["normal", "hover", "pressed", "focus"]:
		var color := "2c433a" if state == "normal" else "41574a"
		theme.set_stylebox(state, "Button", surface(color, "65806a", 8))
	theme.set_color("font_color", "Button", Color("fff3da"))
	theme.set_color("font_pressed_color", "Button", Color("ffe49c"))
	return theme

func card(background: String) -> PanelContainer:
	var item := PanelContainer.new()
	item.add_theme_stylebox_override("panel", surface(background, "597363", 11))
	return item

func icon(key: String) -> Texture2D:
	return load("res://assets/hud/%s.svg" % key)

func picture(key: String, size: int) -> TextureRect:
	var texture := TextureRect.new()
	texture.texture = icon(key)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.custom_minimum_size = Vector2(size, size)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture

func action(value: String, token: String) -> Button:
	var item := button(value)
	item.custom_minimum_size = Vector2(121, 66)
	item.icon = icon(token)
	item.expand_icon = true
	item.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	item.add_theme_constant_override("icon_max_width", 29)
	item.add_theme_font_size_override("font_size", 17)
	item.add_theme_stylebox_override("normal", surface("2e403d", "a6ada0", 14))
	item.add_theme_stylebox_override("disabled", surface("4a5550" if token != "lock" else "6b7168", "9b9f8c", 14))
	item.add_theme_color_override("icon_disabled_color", Color("ece9d6"))
	item.add_theme_color_override("font_disabled_color", Color("dcdcca"))
	return item

func surface(background: String, edge: String, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(edge)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.10, 0.13, 0.11, 0.22)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func label(parent: Control, value: String, size: int, color: String) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", Color(color))
	parent.add_child(item)
	return item

func button(value: String) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = 35
	return item
