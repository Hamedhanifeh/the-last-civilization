extends CanvasLayer

const Economy = preload("res://game/economy.gd")
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
var selected := 0

func configure(model: Economy) -> void:
	economy = model
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = make_theme()
	create_header(root)
	create_footer(root)
	create_people_panel(root)
	economy.changed.connect(refresh)
	refresh()

func create_header(root: Control) -> void:
	var header := HBoxContainer.new()
	root.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 24
	header.offset_right = -24
	header.offset_top = 20
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_card := card("172c2a")
	header.add_child(title_card)
	var title := VBoxContainer.new()
	title_card.add_child(title)
	title.add_theme_constant_override("separation", 0)
	label(title, "The Last Civilization", 25, "fff3da")
	label(title, "کمپ بازماندگان · ۶ نفر", 18, "b5c9ad")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	for resource: String in Economy.RESOURCES:
		var resource_card := card("1c302d")
		resource_card.custom_minimum_size.x = 128
		header.add_child(resource_card)
		var column := VBoxContainer.new()
		resource_card.add_child(column)
		column.add_theme_constant_override("separation", 0)
		var color: String = RESOURCE_COLORS[resource]
		label(column, TITLES[resource], 16, color)
		resource_values[resource] = label(column, "", 23, "fff3da")
		rate_values[resource] = label(column, "", 15, color)

func create_footer(root: Control) -> void:
	var footer := HBoxContainer.new()
	root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24
	footer.offset_right = -24
	footer.offset_top = -95
	footer.offset_bottom = -20
	footer.add_theme_constant_override("separation", 10)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := card("172c2a")
	footer.add_child(info)
	var text := VBoxContainer.new()
	info.add_child(text)
	status = label(text, "", 20, "f6e8c7")
	label(text, "کشیدن برای حرکت · دو انگشت یا چرخ ماوس برای زوم", 15, "b5c9ad")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	people_toggle = button("بازمانده‌ها  ·  ۶")
	people_toggle.custom_minimum_size = Vector2(194, 66)
	people_toggle.add_theme_font_size_override("font_size", 24)
	people_toggle.add_theme_stylebox_override("normal", surface("d7b778", "f1d395", 12))
	people_toggle.add_theme_stylebox_override("hover", surface("e8c886", "f1d395", 12))
	people_toggle.add_theme_color_override("font_color", Color("26342b"))
	people_toggle.add_theme_color_override("font_hover_color", Color("26342b"))
	people_toggle.pressed.connect(toggle_people)
	footer.add_child(people_toggle)

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
	people_toggle.text = "بستن" if panel.visible else "بازمانده‌ها  ·  ۶"

func select_person(index: int) -> void:
	selected = index
	refresh()

func change_job(job: String) -> void:
	economy.assign_job(selected, job)
	refresh()

func refresh() -> void:
	var net := economy.rates()
	for resource: String in Economy.RESOURCES:
		var rate: float = net[resource]
		resource_values[resource].text = "%.1f / %d" % [economy.levels[resource], economy.settings["capacity"][resource]]
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
	status.text = "برای تغییر شغل، بازمانده‌ها را باز کن"
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

func surface(background: String, edge: String, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(edge)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
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
