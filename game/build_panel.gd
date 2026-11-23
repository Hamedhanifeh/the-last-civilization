extends PanelContainer

const Construction = preload("res://game/construction.gd")

signal kind_selected(kind: String)
signal confirmed
signal dismissed
signal site_cancelled
signal preview_cancelled

var choices: Dictionary = {}
var hint: Label
var result: Label
var choose: Button
var cancel_site: Button
var progress_meter: ProgressBar
var cancel_preview: Button
var timings: Dictionary = {}

func configure(model: Construction) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := text(heading, "ساخت‌وساز", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := action(heading, "×")
	close.custom_minimum_size.x = 43
	close.pressed.connect(func() -> void: dismissed.emit())
	for kind: String in model.catalog:
		var item: Dictionary = model.catalog[kind]
		timings[kind] = int(item["seconds"])
		var caption := "%s   ·   %d چوب / %d سنگ" % [item["title"], item["wood"], item["stone"]]
		var option := action(column, caption)
		option.toggle_mode = true
		option.pressed.connect(func() -> void: kind_selected.emit(kind))
		choices[kind] = option
	var divider := HSeparator.new()
	column.add_child(divider)
	hint = text(column, "", 16)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(285, 62)
	progress_meter = ProgressBar.new()
	progress_meter.show_percentage = false
	progress_meter.custom_minimum_size.y = 9
	column.add_child(progress_meter)
	result = text(column, "", 15)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.modulate = Color("f4d783")
	choose = action(column, "تأیید ساخت")
	choose.pressed.connect(func() -> void: confirmed.emit())
	cancel_preview = action(column, "لغو پیش‌نمایش")
	cancel_preview.pressed.connect(func() -> void: preview_cancelled.emit())
	cancel_site = action(column, "لغو ساخت · بازگشت ۸۰٪")
	cancel_site.pressed.connect(func() -> void: site_cancelled.emit())

func update_status(selection: String, issue: String, site_present: bool, progress: float, state: String) -> void:
	for kind: String in choices:
		choices[kind].disabled = site_present
		choices[kind].set_pressed_no_signal(kind == selection)
	choose.visible = not site_present
	choose.disabled = selection.is_empty() or not issue.is_empty()
	cancel_preview.visible = not selection.is_empty() and not site_present
	cancel_site.visible = site_present
	progress_meter.visible = site_present
	progress_meter.value = progress * 100.0
	if site_present:
		hint.text = state
	elif selection.is_empty():
		hint.text = "مزرعه برای دو کشاورز جا دارد. چادر سه جای مسکن اضافه می‌کند."
	elif not issue.is_empty():
		hint.text = issue + "\nروی زمین یک جای دیگر انتخاب کن."
	else:
		hint.text = "کار سازنده %d ثانیه طول می‌کشد. جای دلخواه را روی زمین انتخاب و سپس تأیید کن." % timings[selection]

func notify(message: String) -> void:
	result.text = message
	result.visible = not message.is_empty()

func action(parent: Control, value: String) -> Button:
	var control := Button.new()
	control.text = value
	control.custom_minimum_size.y = 43
	parent.add_child(control)
	return control

func text(parent: Control, value: String, size: int) -> Label:
	var control := Label.new()
	control.text = value
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", Color("fff3da"))
	parent.add_child(control)
	return control
