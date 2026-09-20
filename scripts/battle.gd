extends Control
const Combat = preload("res://scripts/combat.gd")
const Arena = preload("res://scripts/arena.gd")
const BG := Color("101323")
const SURFACE := Color("20263b")
const TEXT := Color("eee3cb")
const MUTED := Color("adb0c3")
const GOLD := Color("e5b969")
var combat = Combat.new()
var arena: Control
var seed_input: LineEdit
var hero_stats: Label
var enemy_stats: Label
var hero_hp: ProgressBar
var enemy_hp: ProgressBar
var turn_label: Label
var intent_label: Label
var journal: RichTextLabel
var result_label: Label
var record_label: Label
var action_buttons: Dictionary = {}
var actions: GridContainer
var stats_row: BoxContainer
var title_row: BoxContainer
var generation := 0
var record := ConfigFile.new()

func _ready() -> void:
	record.load("user://records.cfg")
	make_theme()
	build_ui()
	resized.connect(responsive)
	responsive()
	restart()
	if "--capture" in OS.get_cmdline_user_args():
		capture_preview()

func style(color: Color, border: Color = Color("454b63")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(1)
	s.border_color = border
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func make_theme() -> void:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", MUTED)
	for kind in ["Button", "LineEdit"]:
		t.set_color("font_color", kind, TEXT)
		t.set_stylebox("normal", kind, style(SURFACE))
		t.set_stylebox("focus", kind, style(SURFACE, GOLD))
	t.set_stylebox("hover", "Button", style(Color("35394f"), GOLD))
	t.set_stylebox("pressed", "Button", style(Color("514733"), GOLD))
	t.set_stylebox("disabled", "Button", style(Color("181d2e"), Color("30354b")))
	t.set_color("font_disabled_color", "Button", Color("81879c"))
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 20)
	t.set_constant("h_separation", "GridContainer", 12)
	theme = t

func label(text: String, font_size: int = 18, color: Color = TEXT) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	return item

func build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	content.add_child(label("TOWERS OF DAWN   /   БОЕВОЙ ПРОТОТИП 0.1", 14, GOLD))
	title_row = BoxContainer.new()
	content.add_child(title_row)
	var heading := label("Башни Зари", 40)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(heading)
	var seed_box := VBoxContainer.new()
	seed_box.add_theme_constant_override("separation", 4)
	seed_box.add_child(label("СЕМЯ БОЯ", 12, MUTED))
	seed_input = LineEdit.new()
	seed_input.text = "DAWN-47X9"
	seed_input.max_length = 32
	seed_input.custom_minimum_size = Vector2(230, 44)
	seed_input.tooltip_text = "Одинаковые семя, версия и действия дают одинаковый бой. Enter: начать заново."
	seed_input.text_submitted.connect(func(_text: String): restart())
	seed_box.add_child(seed_input)
	title_row.add_child(seed_box)
	content.add_child(label("01  /  БАШНЯ ПЕПЛА     ·     Зажги первый огонь", 16, MUTED))
	arena = Arena.new()
	arena.custom_minimum_size = Vector2(0, 210)
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(arena)
	stats_row = BoxContainer.new()
	content.add_child(stats_row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(left)
	left.add_child(label("РЫЦАРЬ ЗАРИ", 20, GOLD))
	hero_hp = health_bar(GOLD)
	left.add_child(hero_hp)
	hero_stats = label("", 16, MUTED)
	left.add_child(hero_stats)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(right)
	right.add_child(label("ПЕПЕЛЬНЫЙ СТРАЖ", 20, Color("dc9e95")))
	enemy_hp = health_bar(Color("bf7d78"))
	right.add_child(enemy_hp)
	enemy_stats = label("", 16, MUTED)
	right.add_child(enemy_stats)
	turn_label = label("", 23)
	content.add_child(turn_label)
	intent_label = label("", 16, MUTED)
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intent_label)
	actions = GridContainer.new()
	actions.columns = 3
	content.add_child(actions)
	add_action("attack", "1  Удар мечом\nБесплатно · 1× ATK", "Обычная атака. 5% промах, 10% крит ×1.5.")
	add_action("shield", "2  Щит веры\n4 MP · +12 DEF", "Защита от следующих двух атак врага. Повторное применение обновляет длительность.")
	add_action("execute", "3  Казнь\n6 MP · 1.6× ATK", "Если у врага строго меньше 20% HP, гарантированно добивает. Иначе усиленная атака.")
	result_label = label("", 18, GOLD)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(result_label)
	journal = RichTextLabel.new()
	journal.custom_minimum_size = Vector2(0, 90)
	journal.scroll_following = true
	journal.selection_enabled = true
	journal.add_theme_font_size_override("normal_font_size", 16)
	content.add_child(journal)
	var footer := HBoxContainer.new()
	content.add_child(footer)
	var retry := Button.new()
	retry.text = "Заново с этим семенем"
	retry.custom_minimum_size.y = 46
	retry.pressed.connect(restart)
	footer.add_child(retry)
	record_label = label("", 14, MUTED)
	record_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(record_label)

func health_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 10
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", style(Color("30364c"), Color("30364c")))
	bar.add_theme_stylebox_override("fill", style(color, color))
	return bar

func add_action(key: String, text: String, hint: String) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(0, 68)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(player_action.bind(key))
	actions.add_child(button)
	action_buttons[key] = button

func responsive() -> void:
	if actions == null:
		return
	var narrow := size.x < 720
	actions.columns = 1 if narrow else 3
	stats_row.vertical = narrow
	title_row.vertical = narrow

func restart() -> void:
	generation += 1
	combat.reset(seed_input.text)
	seed_input.text = combat.seed_text
	refresh()
	queue_enemy()

func player_action(action: String) -> void:
	var old_hp: int = combat.enemy.hp
	if not combat.act(action):
		return
	if combat.enemy.hp < old_hp:
		arena.hit("enemy")
	after_action()
	queue_enemy()

func queue_enemy() -> void:
	if combat.finished or combat.actor != "enemy":
		return
	var ticket := generation
	await get_tree().create_timer(0.75).timeout
	if ticket != generation or combat.finished or combat.actor != "enemy":
		return
	var old_hp: int = combat.hero.hp
	combat.enemy_act()
	if combat.hero.hp < old_hp:
		arena.hit("hero")
	after_action()

func after_action() -> void:
	if combat.finished and combat.won:
		var section: String = Combat.RULESET + ":" + combat.seed_text
		var best := int(record.get_value(section, "best_rounds", 999999))
		if combat.round_number < best:
			record.set_value(section, "best_rounds", combat.round_number)
			var err := record.save("user://records.cfg")
			if err != OK:
				combat.history.append("Не удалось записать рекорд: проверь доступ к папке сохранений.")
	refresh()

func refresh() -> void:
	hero_hp.max_value = combat.hero.max_hp
	hero_hp.value = combat.hero.hp
	enemy_hp.max_value = combat.enemy.max_hp
	enemy_hp.value = combat.enemy.hp
	hero_stats.text = "HP %d/%d   MP %d/%d\nATK %d   DEF %d   SPD %d   RES %d" % [combat.hero.hp,combat.hero.max_hp,combat.hero.mp,combat.hero.max_mp,combat.hero.atk,combat.hero.def + (12 if combat.shield_hits > 0 else 0),combat.hero.spd,combat.hero.res]
	enemy_stats.text = "HP %d/%d   MP 0/0\nATK %d   DEF %d   SPD %d   RES %d" % [combat.enemy.hp,combat.enemy.max_hp,combat.enemy.atk,combat.enemy.def,combat.enemy.spd,combat.enemy.res]
	if combat.finished:
		turn_label.text = "Башня пробуждена" if combat.won else "Огонь погас. Но не навсегда."
		result_label.text = "Победа за %d раундов. Попробуй другое семя или улучши результат." % combat.round_number if combat.won else "Поражение. Прикройся щитом перед сокрушением и добей врага Казнью."
	else:
		turn_label.text = "Раунд %02d  /  %s" % [combat.round_number, "Твой ход" if combat.actor == "hero" else "Страж атакует…"]
		result_label.text = "Щит активен: ещё %d атаки врага." % combat.shield_hits if combat.shield_hits > 0 else "Выбери действие. Следующий удар врага показан заранее."
	intent_label.text = "Намерение врага: " + combat.intent()
	for key in action_buttons:
		action_buttons[key].disabled = not combat.can_act(key)
	journal.text = "\n".join(combat.history.slice(maxi(0, combat.history.size() - 30)))
	arena.hero_alive = combat.hero.hp > 0
	arena.enemy_alive = combat.enemy.hp > 0
	arena.shielded = combat.shield_hits > 0
	arena.victory = combat.finished and combat.won
	arena.active_side = combat.actor
	var section: String = Combat.RULESET + ":" + combat.seed_text
	var best := int(record.get_value(section, "best_rounds", 0))
	record_label.text = ("Рекорд семени: %d раундов\n" % best if best > 0 else "Рекорд семени: ещё нет побед\n") + "1 / 2 / 3: действия · Enter в поле семени: новый бой"

func _unhandled_key_input(event: InputEvent) -> void:
	if seed_input.has_focus():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: player_action("attack")
			KEY_2: player_action("shield")
			KEY_3: player_action("execute")

func capture_preview() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://battle-preview.png")
	print("PREVIEW: ", ProjectSettings.globalize_path("user://battle-preview.png"))
	get_tree().quit()
