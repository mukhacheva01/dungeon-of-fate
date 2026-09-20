extends Control
## Real-time top-down prototype. Previous turn-based scene remains untouched.
const BASE := Vector2(1120, 820)
const FIELD := Rect2(48, 170, 1024, 476)
const SPEED := 220.0
const REACH := 87.0
const PORTAL := Vector2(560, 194)
const INK := Color("101323")
const GOLD := Color("e5b969")
const PAPER := Color("eee3cb")
const MUTED := Color("a6adc4")
var player := Vector2(560, 565)
var facing := Vector2.UP
var class_id := "knight"
var hp := 100
var max_hp := 100
var enemies: Array[Dictionary] = []
var walls: Array[Rect2] = [Rect2(236, 310, 64, 64), Rect2(820, 310, 64, 64), Rect2(382, 478, 44, 48), Rect2(696, 478, 44, 48)]
var slash_left := 0.0
var slash_cd := 0.0
var dash_left := 0.0
var dash_cd := 0.0
var invulnerable := 0.0
var hurt_left := 0.0
var time := 0.0
var elapsed := 0.0
var moving := false
var paused := false
var finished := false
var won := false
var strikes := 0
var floaters: Array[Dictionary] = []
var buttons: Dictionary = {}
var touch_held: Dictionary = {}
var touch_fingers: Dictionary = {}
var ui_scale := 1.0
var ui_offset := Vector2.ZERO
var restart_count := 0
var level := 1
var max_level := 10
var boosts: Array[String] = []
var boost_choices: Array[String] = []
var choosing_boost := false
var traps: Array[Dictionary] = []
var healing_pickups: Array[Dictionary] = []
var heal_message_left := 0.0
var trap_message := ""
var trap_message_left := 0.0
var dragon := false
var rng := RandomNumberGenerator.new()
var started := false
var criticals := 0
var last_hit_was_critical := false
var preview_pulse := 0.0

func _ready() -> void:
	get_window().title = "Башни Зари 0.2 | Бег и бой"
	mouse_filter = Control.MOUSE_FILTER_PASS
	configure_input()
	create_buttons()
	resized.connect(layout_buttons)
	layout_buttons()
	restart()
	started = false
	buttons.start.visible = true
	for key in ["left", "up", "down", "right", "attack", "dash", "pause", "restart"]:
		buttons[key].visible = false
	get_window().focus_exited.connect(focus_lost)
	if "--capture" in OS.get_cmdline_user_args():
		capture_preview()

func start_run() -> void:
	started = true
	buttons.start.visible = false
	for key in ["left", "up", "down", "right", "attack", "dash", "pause", "restart"]:
		buttons[key].visible = true
	paused = false
	queue_redraw()

func restart() -> void:
	restart_count += 1
	level = 1
	boosts.clear()
	rng.seed = 0xDA7A
	begin_level()

func begin_level() -> void:
	player = Vector2(560, 565)
	facing = Vector2.UP
	var previous_max_hp := max_hp
	max_hp = max_hp_value()
	hp = max_hp if level == 1 else clampi(hp + (max_hp - previous_max_hp), 1, max_hp)
	enemies.clear()
	traps.clear()
	healing_pickups.clear()
	var scale := 1.0 + (level - 1) * 0.14
	dragon = level == max_level
	if dragon:
		enemies.append(make_enemy(Vector2(560, 320), "Дракон Зари", roundi(360 * scale), 58, "dragon"))
	else:
		var count := mini(3 + int((level - 1) / 3), 6)
		for i in range(count):
			var angle := TAU * float(i) / count
			var radius := 120.0 + float((i * 29 + level * 17) % 70)
			var pos := Vector2(560, 390) + Vector2.from_angle(angle) * radius
			pos = safe_enemy_spawn(pos, i)
			var enemy_kinds := ["guard", "sentinel", "archer", "mage", "golem", "shade"]
			var kind: String = enemy_kinds[(i + level - 1) % enemy_kinds.size()]
			enemies.append(make_enemy(pos, kind_name(kind), roundi((56 if kind == "guard" else 42) * scale), 70 + level * 2, kind))
	for i in range(mini(1 + int((level - 1) / 2), 5)):
		var trap_positions := [Vector2(320, 255), Vector2(800, 255), Vector2(320, 535), Vector2(800, 535), Vector2(560, 430)]
		traps.append({"pos": trap_positions[(i + level) % trap_positions.size()], "kind": ["fire", "ice", "spike"][i % 3], "armed": true, "flash": 0.0})
	var heal_positions := [Vector2(170, 430), Vector2(930, 430), Vector2(560, 260)]
	for i in range(1 + int(level / 4)):
		healing_pickups.append({"pos": heal_positions[(i + level) % heal_positions.size()], "active": true, "pulse": i})
	slash_left = 0
	slash_cd = 0
	dash_left = 0
	dash_cd = 0
	invulnerable = 0
	hurt_left = 0
	if level == 1:
		max_hp = max_hp_value()
		hp = max_hp
	elapsed = 0 if level == 1 else elapsed
	strikes = 0 if level == 1 else strikes
	finished = false
	won = false
	choosing_boost = false
	boost_choices.clear()
	paused = false
	moving = false
	trap_message = ""
	trap_message_left = 0
	floaters.clear()
	touch_held.clear()
	touch_fingers.clear()
	set_boost_buttons(false)
	queue_redraw()

func safe_enemy_spawn(candidate: Vector2, index: int) -> Vector2:
	var fallback := [Vector2(390, 285), Vector2(730, 285), Vector2(560, 350), Vector2(390, 555), Vector2(730, 555), Vector2(560, 515)]
	var point := Vector2(clampf(candidate.x, 120.0, 1000.0), clampf(candidate.y, 245.0, 590.0))
	for wall in walls:
		if wall.grow(52).has_point(point):
			point = fallback[index % fallback.size()]
	if point.y < 245.0:
		point.y = 245.0
	return point

func kind_name(kind: String) -> String:
	return {"guard":"Костяной страж", "sentinel":"Часовой", "archer":"Пепельный лучник", "mage":"Сумеречный маг", "golem":"Руинный голем", "shade":"Тень"}.get(kind, "Враг")

func make_enemy(pos: Vector2, title: String, health: int, speed: float, kind: String = "guard") -> Dictionary:
	return {"pos": pos, "name": title, "kind": kind, "hp": health, "max_hp": health, "speed": speed, "face": Vector2.DOWN, "state": "chase", "timer": 0.0, "flash": 0.0, "moving": false, "phase": 1}

func get_class_name() -> String:
	return {"knight":"Рыцарь", "spellcaster":"Заклинатель", "hunter":"Охотник"}.get(class_id, "Рыцарь")

func choose_class(next_class: String) -> void:
	if next_class in ["knight", "spellcaster", "hunter"] and not started:
		class_id = next_class
		max_hp = max_hp_value()
		hp = max_hp
		queue_redraw()

func max_hp_value() -> int:
	var base := 100
	if class_id == "spellcaster":
		base = 82
	elif class_id == "hunter":
		base = 92
	return base + (20 if "vitality" in boosts else 0)

func create_buttons() -> void:
	for key in ["left", "up", "down", "right", "attack", "dash", "boost1", "boost2", "boost3", "pause", "restart", "start"]:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.text = {"left":"←", "up":"↑", "down":"↓", "right":"→", "attack":"⚔  УДАР  · Space", "dash":"✦  РЫВОК  · Shift", "boost1":"", "boost2":"", "boost3":"", "pause":"Пауза", "restart":"Заново", "start":"НАЧАТЬ ЗАБЕГ"}[key]
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = false
		if key.begins_with("boost"):
			button.add_theme_font_size_override("font_size", 15)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("242b42")
		normal.border_color = Color("566079")
		normal.set_border_width_all(1)
		var active := normal.duplicate()
		active.bg_color = Color("51452f")
		active.border_color = GOLD
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", active)
		button.add_theme_stylebox_override("pressed", active)
		button.add_theme_color_override("font_color", PAPER)
		button.add_theme_color_override("font_hover_color", GOLD)
		button.add_theme_color_override("font_pressed_color", GOLD)
		if key == "restart":
			button.pressed.connect(restart)
		elif key == "pause":
			button.pressed.connect(toggle_pause)
		elif key.begins_with("boost"):
			button.pressed.connect(select_boost.bind(int(key.substr(5)) - 1))
		elif key == "start":
			button.pressed.connect(start_run)
		else:
			button.button_down.connect(func(): touch_held[key] = true)
			button.button_up.connect(func(): touch_held[key] = false)
		add_child(button)
		buttons[key] = button

func button_rect(key: String) -> Rect2:
	return {"left":Rect2(48, 720, 60, 58), "up":Rect2(112, 660, 60, 58), "down":Rect2(112, 720, 60, 58), "right":Rect2(176, 720, 60, 58), "attack":Rect2(648, 693, 207, 70), "dash":Rect2(867, 693, 205, 70), "boost1":Rect2(216, 420, 220, 76), "boost2":Rect2(450, 420, 220, 76), "boost3":Rect2(684, 420, 220, 76), "start":Rect2(430, 610, 260, 62), "pause":Rect2(856, 38, 102, 42), "restart":Rect2(970, 38, 102, 42)}[key]

func layout_buttons() -> void:
	ui_scale = minf(size.x / BASE.x, size.y / BASE.y)
	ui_offset = (size - BASE * ui_scale) / 2
	for key in buttons:
		var rect := button_rect(key)
		buttons[key].position = ui_offset + rect.position * ui_scale
		buttons[key].size = rect.size * ui_scale
		buttons[key].add_theme_font_size_override("font_size", maxi(12, roundi(17 * ui_scale)))
	queue_redraw()

func focus_lost() -> void:
	if not finished:
		paused = true
	touch_held.clear()
	touch_fingers.clear()

func toggle_pause() -> void:
	if not finished:
		paused = not paused
		touch_held.clear()
		touch_fingers.clear()

func held(key: String) -> bool:
	return bool(touch_held.get(key, false)) or touch_fingers.values().has(key)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not event.pressed:
			touch_fingers.erase(event.index)
		else:
			var point: Vector2 = (event.position - ui_offset) / ui_scale
			for key in ["left", "right", "up", "down", "attack", "dash"]:
				if button_rect(key).has_point(point):
					touch_fingers[event.index] = key
					get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if touch_fingers.has(event.index):
			var point: Vector2 = (event.position - ui_offset) / ui_scale
			var found := false
			for key in ["left", "right", "up", "down", "attack", "dash"]:
				if button_rect(key).has_point(point):
					touch_fingers[event.index] = key
					found = true
			if not found:
				touch_fingers.erase(event.index)
	elif event is InputEventKey and event.pressed and not event.echo:
		if not started:
			if event.physical_keycode == KEY_1: choose_class("knight")
			elif event.physical_keycode == KEY_2: choose_class("spellcaster")
			elif event.physical_keycode == KEY_3: choose_class("hunter")
		if event.physical_keycode == KEY_ESCAPE:
			toggle_pause()
		elif event.physical_keycode == KEY_R:
			restart()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = (event.position - ui_offset) / ui_scale
		if FIELD.has_point(point) and not paused and not finished:
			if point.distance_to(player) > 2:
				facing = (point - player).normalized()
			attack()

func configure_input() -> void:
	var bindings := {"left":[KEY_A, KEY_LEFT], "right":[KEY_D, KEY_RIGHT], "up":[KEY_W, KEY_UP], "down":[KEY_S, KEY_DOWN], "attack":[KEY_SPACE], "dash":[KEY_SHIFT]}
	for key in bindings:
		var action: String = "dawn_" + key
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for code in bindings[key]:
				var event := InputEventKey.new()
				event.physical_keycode = code
				InputMap.action_add_event(action, event)

func _physics_process(delta: float) -> void:
	if not started:
		time += delta
		queue_redraw()
		return
	var movement := Vector2.ZERO
	movement.x = float(Input.is_action_pressed("dawn_right") or held("right")) - float(Input.is_action_pressed("dawn_left") or held("left"))
	movement.y = float(Input.is_action_pressed("dawn_down") or held("down")) - float(Input.is_action_pressed("dawn_up") or held("up"))
	step(delta, movement, Input.is_action_pressed("dawn_attack") or held("attack"), Input.is_action_pressed("dawn_dash") or held("dash"))
	buttons.pause.text = "Продолжить" if paused else "Пауза"
	queue_redraw()

func step(delta: float, direction: Vector2, attacking: bool = false, dashing: bool = false) -> void:
	if not started or paused or finished or choosing_boost:
		return
	time += delta
	elapsed += delta
	trap_message_left = maxf(0, trap_message_left - delta)
	slash_cd = maxf(0, slash_cd - delta)
	slash_left = maxf(0, slash_left - delta)
	dash_cd = maxf(0, dash_cd - delta)
	dash_left = maxf(0, dash_left - delta)
	invulnerable = maxf(0, invulnerable - delta)
	hurt_left = maxf(0, hurt_left - delta)
	for i in range(floaters.size() - 1, -1, -1):
		floaters[i].life -= delta
		floaters[i].pos.y -= delta * 34
		if floaters[i].life <= 0:
			floaters.remove_at(i)
	var input := direction.limit_length(1)
	moving = input.length_squared() > 0.01
	if moving and dash_left <= 0 and slash_left <= 0:
		facing = input.normalized()
	if dashing and dash_cd <= 0:
		dash_left = 0.16
		dash_cd = 1.0 * (0.65 if "dash" in boosts else 1.0)
		invulnerable = maxf(invulnerable, 0.23)
	var velocity := facing * 600 if dash_left > 0 else input * (SPEED * (1.2 if "haste" in boosts else 1.0))
	player = move_body(player, velocity * delta, 14)
	if attacking:
		attack()
	for enemy in enemies:
		update_enemy(enemy, delta)
		if finished:
			break
	check_traps()
	check_healing_pickups()
	if not finished and living_enemies() == 0 and player.distance_to(PORTAL) < 46:
		if level >= max_level:
			finished = true
			won = true
		else:
			open_boost_choice()

func open_boost_choice() -> void:
	if choosing_boost:
		return
	choosing_boost = true
	boost_choices = ["vitality", "blade", "dash", "armor", "flame", "frost", "haste"]
	boost_choices.shuffle()
	boost_choices = boost_choices.slice(0, 3)
	set_boost_buttons(true)
	trap_message = "Башня захвачена. Выбери один буст для следующего уровня."
	trap_message_left = 99
	queue_redraw()

func select_boost(index: int) -> void:
	if not choosing_boost or index < 0 or index >= boost_choices.size():
		return
	boosts.append(boost_choices[index])
	choosing_boost = false
	set_boost_buttons(false)
	level += 1
	begin_level()

func boost_title(boost: String) -> String:
	return {"vitality":"ЖИВУЧЕСТЬ\n+20 HP", "blade":"ОСТРОЕ ЛЕЗВИЕ\n+8 УРОНА", "dash":"СТРЕМИТЕЛЬНЫЙ РЫВОК\n−35% ПЕРЕЗАРЯДКИ", "armor":"СТАЛЬНАЯ БРОНЯ\n−4 УРОНА", "flame":"ПЫЛАЮЩИЙ УДАР\n+8 УРОНА", "frost":"ЛЕДЯНОЙ СЛЕД\nВРАГИ МЕДЛЕННЕЕ", "haste":"ЛЁГКИЕ НОГИ\n+20% СКОРОСТИ"}.get(boost, boost)

func set_boost_buttons(visible: bool) -> void:
	for i in range(3):
		var key := "boost%d" % (i + 1)
		if buttons.has(key):
			buttons[key].visible = visible
			buttons[key].text = boost_title(boost_choices[i]) if visible and i < boost_choices.size() else ""
	for key in ["attack", "dash"]:
		if buttons.has(key):
			buttons[key].visible = not visible

func check_traps() -> void:
	for trap in traps:
		if not trap.armed:
			continue
		if player.distance_to(trap.pos) > 25:
			continue
		trap.armed = false
		trap.flash = 0.45
		match trap.kind:
			"fire":
				damage_player(maxi(5, 15 - (4 if "armor" in boosts else 0)))
				trap_message = "ОГНЕННАЯ ЛОВУШКА: потеряно здоровье"
			"ice":
				dash_left = 0
				dash_cd = maxf(dash_cd, 1.4)
				trap_message = "ЛЕДЯНАЯ ЛОВУШКА: рывок заблокирован"
			"spike":
				damage_player(maxi(4, 11 - (4 if "armor" in boosts else 0)))
				facing = -facing
				trap_message = "ШИПЫ: удар отбросил рыцаря"
		trap_message_left = 2.0
		floaters.append({"pos": trap.pos + Vector2(-58, -28), "text": "ЛОВУШКА", "life": 0.9, "color": Color("ee9b8b")})

func check_healing_pickups() -> void:
	if hp >= max_hp:
		return
	for pickup in healing_pickups:
		if pickup.active and player.distance_to(pickup.pos) <= 25:
			var old_hp := hp
			hp = mini(max_hp, hp + 5)
			pickup.active = false
			heal_message_left = 1.2
			floaters.append({"pos": pickup.pos + Vector2(-24, -28), "text": "+%d HP" % (hp - old_hp), "life": 0.9, "color": Color("8bd1ca")})

func valid_position(point: Vector2, radius: float) -> bool:
	if not FIELD.grow(-radius).has_point(point):
		return false
	for wall in walls:
		if wall.grow(radius).has_point(point):
			return false
	return true

func move_body(origin: Vector2, displacement: Vector2, radius: float) -> Vector2:
	# Substeps prevent tunnelling through ruins during a dash or slow frame.
	var result := origin
	var count := maxi(1, ceili(displacement.length() / 6.0))
	var increment := displacement / count
	for i in range(count):
		var next := result + Vector2(increment.x, 0)
		if valid_position(next, radius):
			result = next
		next = result + Vector2(0, increment.y)
		if valid_position(next, radius):
			result = next
	return result

func attack() -> bool:
	if finished or paused or slash_cd > 0:
		return false
	slash_cd = 0.38
	slash_left = 0.20
	strikes += 1
	last_hit_was_critical = false
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		var offset: Vector2 = enemy.pos - player
		var attack_range: float = 87.0 if class_id == "knight" else (260.0 if class_id == "spellcaster" else 210.0)
		var cone_ok: bool = offset.length() < 1 or facing.dot(offset.normalized()) > (-0.2 if class_id != "knight" else 0.15)
		if offset.length() <= attack_range and cone_ok and clear_line(player, enemy.pos):
			var hit_damage: int = (22 if class_id == "knight" else (30 if class_id == "spellcaster" else 18)) + (8 if "blade" in boosts else 0) + (8 if "flame" in boosts else 0)
			var critical := rng.randf() < 0.15
			if critical:
				hit_damage = roundi(hit_damage * 1.75)
				criticals += 1
				last_hit_was_critical = true
			enemy.hp = maxi(0, enemy.hp - hit_damage)
			if class_id == "hunter" and enemy.hp > 0:
				enemy.hp = maxi(0, enemy.hp - 9)
			enemy.flash = 0.22
			enemy.pos = move_body(enemy.pos, offset.normalized() * 14, 16)
			floaters.append({"pos": enemy.pos + Vector2(-8, -52), "text": ("КРИТ! %d" % hit_damage) if critical else str(hit_damage), "life": 0.9 if critical else 0.65, "color": Color("f5c66e") if critical else GOLD})
	return true

func clear_line(start: Vector2, end: Vector2) -> bool:
	var length := start.distance_to(end)
	var samples := maxi(1, ceili(length / 5))
	for i in range(samples + 1):
		var point := start.lerp(end, float(i) / samples)
		for wall in walls:
			if wall.has_point(point):
				return false
	return true

func update_enemy(enemy: Dictionary, delta: float) -> void:
	if enemy.hp <= 0:
		return
	if dragon:
		var ratio: float = float(enemy.hp) / enemy.max_hp
		enemy.phase = 1 if ratio > 0.66 else (2 if ratio > 0.33 else 3)
	enemy.flash = maxf(0, enemy.flash - delta)
	enemy.timer = maxf(0, enemy.timer - delta)
	enemy.moving = false
	var offset: Vector2 = player - enemy.pos
	if enemy.state == "windup":
		if enemy.timer <= 0:
			if offset.length() < 76 and (offset.length() < 1 or enemy.face.dot(offset.normalized()) > 0.25) and clear_line(enemy.pos, player):
				var dragon_crit: bool = dragon and rng.randf() < (0.12 + 0.08 * enemy.phase)
				var base_damage: int = 14 + (4 if dragon and enemy.phase >= 2 else 0) + (6 if dragon and enemy.phase >= 3 else 0)
				if dragon_crit:
					base_damage = roundi(base_damage * 1.6)
					floaters.append({"pos": player + Vector2(-30, -70), "text": "ДРАКОН КРИТ!", "life": 0.9, "color": Color("f08f72")})
				damage_player(base_damage)
				if dragon and enemy.phase >= 2:
					for pickup in healing_pickups:
						if pickup.active and pickup.pos.distance_to(player) < 150:
							pickup.active = false
			enemy.state = "recover"
			enemy.timer = 0.7
		return
	if enemy.state == "recover":
		if enemy.timer <= 0:
			enemy.state = "chase"
		return
	if offset.length() < (65.0 + enemy.phase * 12.0 if dragon else 65.0) and clear_line(enemy.pos, player):
		enemy.face = offset.normalized() if offset.length() > 1 else Vector2.DOWN
		enemy.state = "windup"
		enemy.timer = 0.65
		return
	var heading := offset.normalized()
	for other in enemies:
		if other == enemy or other.hp <= 0:
			continue
		var apart: Vector2 = enemy.pos - other.pos
		if apart.length() < 40 and apart.length() > 0.1:
			heading += apart.normalized() * 0.6
	heading = heading.normalized()
	var previous: Vector2 = enemy.pos
	var next := move_body(previous, heading * enemy.speed * (0.72 if "frost" in boosts else 1.0) * delta, 16)
	# Try tangents when a pillar blocks the chase. No global pathfinding yet.
	if next.distance_to(previous) < enemy.speed * delta * 0.15:
		var tangent := Vector2(-heading.y, heading.x)
		next = move_body(previous, tangent * enemy.speed * delta, 16)
		if next.distance_to(previous) < 0.1:
			next = move_body(previous, -tangent * enemy.speed * delta, 16)
	next.x = clampf(next.x, 92.0, 1028.0)
	next.y = clampf(next.y, 245.0, 610.0)
	if not valid_position(next, 16):
		next = previous
	enemy.pos = next
	enemy.moving = next.distance_to(previous) > 0.1
	enemy.face = heading

func damage_player(amount: int) -> void:
	if invulnerable > 0 or finished:
		return
	var final_amount: int = maxi(1, amount - (4 if "armor" in boosts else 0))
	hp = maxi(0, hp - final_amount)
	invulnerable = 0.65
	hurt_left = 0.20
	floaters.append({"pos":player + Vector2(-8, -55), "text":"−%d" % final_amount, "life":0.65, "color":Color("ee9b8b")})
	if hp <= 0:
		finished = true
		won = false

func living_enemies() -> int:
	var total := 0
	for enemy in enemies:
		if enemy.hp > 0:
			total += 1
	return total

func rect(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(x, y, width, height), color)

func text_at(value: String, at: Vector2, font_size: int = 18, color: Color = PAPER) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_set_transform(ui_offset, 0, Vector2.ONE * ui_scale)
	text_at("TOWERS OF DAWN  /  ПРОТОТИП 0.2", Vector2(48, 32), 13, GOLD)
	text_at("Башни Зари", Vector2(48, 77), 36)
	text_at("%02d / %s" % [level, "СЕРДЦЕ ДРАКОНА" if dragon else "ДВОР БАШНИ ПЕПЛА"], Vector2(48, 108), 17, Color("eaa46b") if dragon else MUTED)
	text_at(get_class_name().to_upper(), Vector2(390, 58), 13, GOLD if class_id != "knight" else MUTED)
	rect(390, 71, 228, 10, Color("34394f"))
	rect(390, 71, 228.0 * hp / max_hp, 10, GOLD if hp > max_hp * 0.3 else Color("dc8578"))
	text_at("%d / %d HP" % [hp, max_hp], Vector2(633, 82), 17)
	var total_enemies := enemies.size()
	var defeated_enemies := total_enemies - living_enemies()
	var goal := "Победи дракона в трёх фазах" if dragon else ("Одолей стражей и войди в башню" if living_enemies() > 0 else "Путь открыт! Подойди к золотым воротам ↑")
	text_at(goal, Vector2(48, 136), 18, GOLD if living_enemies() == 0 or dragon else PAPER)
	if dragon and living_enemies() > 0:
		text_at("ФАЗА %d / 3" % enemies[0].phase, Vector2(890, 136), 17, Color("eaa46b"))
	text_at("Побеждено: %d / %d    %02d:%02d" % [defeated_enemies, total_enemies, int(elapsed) / 60, int(elapsed) % 60], Vector2(785, 116), 15, MUTED)
	if trap_message_left > 0:
		text_at(trap_message, Vector2(430, 160), 14, Color("ee9b8b"))
	draw_world()
	# Draw actors in Y order for top-down depth.
	var actors: Array[Dictionary] = []
	for enemy in enemies:
		if enemy.hp > 0:
			actors.append(enemy)
	actors.append({"pos":player, "hero":true})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)
	for actor in actors:
		if actor.has("hero"):
			if hp > 0:
				draw_knight(player, facing, false, moving, hurt_left > 0, slash_left > 0)
		else:
			draw_enemy_sprite(actor)
			var pos: Vector2 = actor.pos
			rect(pos.x - 20, pos.y - 64, 40, 4, Color("34394f"))
			rect(pos.x - 20, pos.y - 64, 40.0 * actor.hp / actor.max_hp, 4, Color("c08083"))
	if slash_left > 0:
		var angle := facing.angle()
		var progress := 1.0 - slash_left / 0.20
		draw_arc(player + Vector2(0, -10), 68, angle - 1.15 + progress * 0.4, angle + 1.15, 16, GOLD, 5, false)
		draw_arc(player + Vector2(0, -10), 78, angle - 0.9 + progress * 0.4, angle + 0.85, 12, PAPER, 2, false)
	for floater in floaters:
		text_at(floater.text, floater.pos, 24, floater.color)
	text_at("WASD / стрелки: бежать", Vector2(268, 699), 18)
	text_at("Пробел / клик: ударить", Vector2(268, 728), 18, MUTED)
	text_at("Shift: рывок · Esc: пауза · R: заново", Vector2(268, 757), 14, MUTED)
	text_at("Враг замахнулся? Выйди из красного сектора.", Vector2(48, 805), 15, MUTED)
	text_at("Рывок готов" if dash_cd <= 0 else "Рывок: %.1f с" % dash_cd, Vector2(884, 789), 14, GOLD if dash_cd <= 0 else MUTED)
	if not started:
		draw_preview_scene()
		rect(176, 218, 768, 370, Color("171d31", 0.93))
		draw_rect(Rect2(176, 218, 768, 370), GOLD, false, 2)
		text_at("TOWERS OF DAWN", Vector2(318, 294), 38, GOLD)
		text_at("БАШНИ ЗАРИ", Vector2(402, 331), 24, PAPER)
		text_at("Двор Пепла  ·  уровень 01", Vector2(420, 377), 17, MUTED)
		text_at("Класс: %s   [1] Рыцарь  [2] Заклинатель  [3] Охотник" % get_class_name(), Vector2(300, 405), 15, GOLD)
		text_at("Беги. Уклоняйся. Руби. Зажги все 10 башен.", Vector2(294, 431), 19, PAPER)
		text_at("После каждой башни выбери один из трёх бустов.", Vector2(313, 462), 16, MUTED)
		text_at("WASD / стрелки   движение     Space   удар     Shift   рывок", Vector2(263, 514), 14, Color("8792aa"))
	if choosing_boost:
		rect(168, 330, 784, 210, Color("171d31"))
		draw_rect(Rect2(168, 330, 784, 210), GOLD, false, 2)
		text_at("БАШНЯ ЗАЖЖЕНА", Vector2(400, 365), 24, GOLD)
		text_at("Выбери одну силу для следующего уровня", Vector2(341, 391), 16, MUTED)
	if finished or paused:
		rect(240, 316, 640, 176, Color("20263b"))
		draw_rect(Rect2(240, 316, 640, 176), GOLD, false, 2)
		var heading := "Башня пробуждена!" if won else "Рыцарь пал"
		if paused and not finished:
			heading = "Пауза"
		text_at(heading, Vector2(278, 373), 32, GOLD)
		var message := "Нажми Esc или «Продолжить», чтобы вернуться."
		if finished:
			message = "Победа за %d с. Ударов: %d. R: ещё один бой." % [int(elapsed), strikes] if won else "Не стой перед замахом. R: попробовать снова."
		text_at(message, Vector2(278, 415), 18)
		text_at("Бой в реальном времени, без очереди ходов.", Vector2(278, 455), 16, MUTED)

func draw_preview_scene() -> void:
	# A living poster: the cast breathes and the dragon wings loop behind the title.
	var hero_pos := Vector2(330 + sin(time * 1.4) * 8, 470 + sin(time * 3.0) * 3)
	var foe_positions := [Vector2(240, 350), Vector2(860, 355), Vector2(260, 505)]
	var foe_kinds := ["guard", "archer", "mage"]
	for i in range(foe_positions.size()):
		var foe := make_enemy(foe_positions[i], kind_name(foe_kinds[i]), 1, 0, foe_kinds[i])
		foe.moving = true
		foe.face = (hero_pos - foe_positions[i]).normalized()
		draw_enemy_sprite(foe)
	var boss := make_enemy(Vector2(820 + sin(time * 1.1) * 12, 290), "Дракон Зари", 1, 0, "dragon")
	boss.face = Vector2.LEFT
	draw_enemy_sprite(boss)
	draw_knight(hero_pos, Vector2.RIGHT, false, true, false, sin(time * 4.0) > 0.4)
	for i in range(8):
		var ember := Vector2(740 + sin(time * 2.0 + i) * 42, 230 + fmod(time * 35.0 + i * 26.0, 150.0))
		draw_circle(ember, 2 + (i % 2), Color("f0b36f", 0.75))
	text_at("THE DAWNBOUND", Vector2(712, 400), 12, Color("f0b36f", 0.8))

func draw_world() -> void:
	rect(40, 162, 1040, 492, Color("50536c"))
	draw_rect(FIELD, Color("252b3e"))
	for y in range(180, 645, 32):
		for x in range(52, 1070, 32):
			var shade := Color("2b3045") if (x / 32 + y / 32) % 2 == 0 else Color("292e41")
			rect(x, y, 30, 30, shade)
			if (x * 3 + y) % 7 == 0:
				rect(x + 8, y + 23, 10, 2, Color("3b4254"))
	# Zone bands make the floor readable at a glance.
	draw_rect(Rect2(50, 224, 1020, 118), Color("29364a"), false, 2)
	draw_rect(Rect2(50, 378, 1020, 112), Color("302f49"), false, 2)
	draw_rect(Rect2(50, 526, 1020, 102), Color("3a2f43"), false, 2)
	text_at("СЕВЕРНЫЙ ДВОР", Vector2(66, 247), 11, Color("68748d"))
	text_at("РУИНЫ ПЕПЛА", Vector2(66, 401), 11, Color("75647c"))
	text_at("ПУТЬ К ВОРОТАМ", Vector2(66, 549), 11, Color("7d6c73"))
	for x in range(90, 1030, 80):
		draw_line(Vector2(x, 252), Vector2(x + 22, 270), Color("39455a"), 2)
		draw_line(Vector2(x + 38, 438), Vector2(x + 62, 430), Color("463d58"), 2)
	# Northern tower gate and stepped stone walls.
	rect(470, 166, 180, 55, Color("3d425c"))
	rect(514, 170, 92, 51, INK)
	var lit := living_enemies() == 0
	rect(524, 174, 72, 42, GOLD if lit else Color("655260"))
	for x in range(531, 595, 15):
		rect(x, 174, 5, 43, Color("f0d39a") if lit else INK)
	if lit:
		draw_arc(PORTAL + Vector2(0, 31), 38 + sin(time * 4) * 3, 0, TAU, 24, GOLD, 2)
	for wall in walls:
		draw_rect(wall.grow(5), Color("171d30"))
		draw_rect(wall, Color("444c66"))
		draw_rect(Rect2(wall.position, Vector2(wall.size.x, 9)), Color("69718a"))
		draw_line(wall.position + Vector2(0, 27), wall.position + Vector2(wall.size.x, 27), Color("252a3d"), 3)
	for pickup in healing_pickups:
		if pickup.active:
			var heal_pos: Vector2 = pickup.pos
			var heal_pulse := 1.0 + sin(time * 5.0 + pickup.pulse) * 0.12
			draw_circle(heal_pos, 24 * heal_pulse, Color("8bd1ca", 0.12))
			draw_arc(heal_pos, 20 * heal_pulse, 0, TAU, 16, Color("8bd1ca"), 2)
			draw_colored_polygon(PackedVector2Array([heal_pos + Vector2(0, -14), heal_pos + Vector2(9, 0), heal_pos + Vector2(0, 14), heal_pos + Vector2(-9, 0)]), Color("8bd1ca"))
			text_at("+5 HP", heal_pos + Vector2(-18, 40), 12, Color("8bd1ca"))
	for trap in traps:
		var tp: Vector2 = trap.pos
		var trap_color := Color("dc8578") if trap.kind == "fire" else (Color("81b4c4") if trap.kind == "ice" else Color("c4a06b"))
		if trap.armed:
			draw_circle(tp, 44 + sin(time * 4 + tp.x) * 3, Color(trap_color, 0.10))
			draw_arc(tp, 44 + sin(time * 4 + tp.x) * 3, 0, TAU, 32, trap_color, 3)
			draw_circle(tp, 26, Color(trap_color, 0.22))
			for i in range(8):
				var ray := Vector2.from_angle(i * TAU / 8.0)
				draw_line(tp + ray * 9, tp + ray * 23, trap_color, 3)
			text_at("🔥  ОГОНЬ" if trap.kind == "fire" else ("❄  ЛЁД" if trap.kind == "ice" else "✦  ШИПЫ"), tp + Vector2(-30, 52), 13, trap_color)
			text_at("ОПАСНАЯ ЗОНА", tp + Vector2(-44, -50), 10, Color(trap_color, 0.86))
		else:
			draw_circle(tp, 18, Color("50536c"))
	for p in [Vector2(108, 220), Vector2(1010, 220), Vector2(108, 592), Vector2(1010, 592)]:
		rect(p.x - 5, p.y, 12, 18, Color("666078"))
		rect(p.x - 9, p.y - 6, 20, 8, Color("997753"))
		var flicker := int(time * 8) % 3
		rect(p.x - 5, p.y - 19 - flicker, 12, 15 + flicker, Color("c97552"))
		rect(p.x - 1, p.y - 16 - flicker, 5, 12, GOLD)
	for enemy in enemies:
		if enemy.hp <= 0:
			var p: Vector2 = enemy.pos
			var death_pulse := 1.0 + sin(time * 8.0 + p.x) * 0.15
			draw_circle(p + Vector2(0, -12), 28 * death_pulse, Color("c08083", 0.16))
			rect(p.x - 17, p.y - 6, 30, 9, Color("5f4e60"))
			rect(p.x + 8, p.y - 12, 7, 5, Color("9c8495"))
			for i in range(4):
				var spark := p + Vector2.from_angle(time * 1.8 + i * TAU / 4.0) * (22.0 + sin(time * 6 + i) * 5.0)
				draw_rect(Rect2(spark, Vector2(4, 4)), Color("e5b969", 0.72))
		elif enemy.state == "windup":
			var center: Vector2 = enemy.pos
			var angle: float = enemy.face.angle()
			var points := PackedVector2Array([center])
			for i in range(13):
				points.append(center + Vector2.from_angle(angle - 1.15 + i * 2.3 / 12) * 76)
			draw_colored_polygon(points, Color("704b52"))
			draw_arc(center, 76, angle - 1.15, angle + 1.15, 16, Color("f0a28d"), 2)
			text_at("!", center + Vector2(-4, -72), 23, Color("f0a28d"))

func draw_enemy_sprite(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy.pos
	var kind: String = enemy.kind
	var dir: Vector2 = enemy.face
	var bob := sin(time * (10.0 if enemy.moving else 2.8) + pos.x * 0.04) * (2.5 if enemy.moving else 0.8)
	var hit: bool = enemy.flash > 0
	var pulse := 1.0 + sin(time * 8.0 + pos.x) * 0.04
	var main := Color("a47b86")
	var dark := Color("4d3549")
	var glow := Color("db8e82")
	if kind == "archer":
		main = Color("c69b72"); dark = Color("534034"); glow = Color("e9b56d")
	elif kind == "mage":
		main = Color("8e82bd"); dark = Color("393453"); glow = Color("aeb8f1")
	elif kind == "golem":
		main = Color("828b9b"); dark = Color("3f4858"); glow = Color("d5a56d")
	elif kind == "shade":
		main = Color("65738e"); dark = Color("282d48"); glow = Color("8bd1ca")
	elif kind == "dragon":
		main = Color("b86552"); dark = Color("4a2933"); glow = Color("f0b36f")
	if hit:
		main = PAPER; glow = GOLD
	var p := pos + Vector2(-18, -52 + bob)
	draw_ellipse_shadow(pos)
	if kind == "dragon":
		draw_circle(pos + Vector2(0, -24), 34 * pulse, Color(dark, 0.9))
		for wing in [-1.0, 1.0]:
			var wing_tip := pos + Vector2(wing * 46, -48 - bob)
			draw_colored_polygon(PackedVector2Array([pos + Vector2(wing * 8, -30), pos + Vector2(wing * 48, -55), wing_tip + Vector2(wing * 8, 24), pos + Vector2(wing * 14, 6)]), main)
		rect(p.x + 5, p.y + 12, 28, 28, main)
		rect(p.x + 12, p.y + 4, 18, 16, main)
		rect(p.x + 6, p.y + 2, 6, 14, glow)
		rect(p.x + 29, p.y + 2, 6, 14, glow)
		draw_line(pos + Vector2(0, -4), pos + dir * 48 + Vector2(0, -4), glow, 4)
		text_at("DRAGON", pos + Vector2(-28, -78), 10, glow)
		return
	if kind == "archer":
		# Hood, bow and quiver.
		draw_colored_polygon(PackedVector2Array([p + Vector2(5, 5), p + Vector2(29, 5), p + Vector2(34, 27), p + Vector2(1, 27)]), dark)
		rect(p.x + 8, p.y + 12, 20, 27, main); rect(p.x + 12, p.y + 4, 12, 10, glow)
		draw_arc(pos + dir * 15, 27, -1.2, 1.2, 12, glow, 3)
		draw_line(pos + dir * 12 - Vector2(0, 22), pos + dir * 12 + Vector2(0, 22), PAPER, 2)
		draw_line(pos + dir * 12, pos + dir * 12 + dir * 35, glow, 2)
	elif kind == "mage":
		# Robe, tall hat and floating spell orb.
		draw_colored_polygon(PackedVector2Array([p + Vector2(6, 16), p + Vector2(30, 16), p + Vector2(39, 49), p + Vector2(-3, 49)]), main)
		draw_colored_polygon(PackedVector2Array([p + Vector2(2, 9), p + Vector2(34, 9), p + Vector2(21, -16)]), dark)
		rect(p.x + 12, p.y + 9, 12, 9, glow)
		draw_circle(pos + Vector2(30, -32) + Vector2(0, sin(time * 5) * 4), 7, glow)
		draw_arc(pos + Vector2(30, -32), 13, 0, TAU, 12, Color(glow, 0.55), 2)
	elif kind == "golem":
		# Wide stone silhouette with glowing core.
		rect(p.x, p.y + 9, 37, 38, dark)
		rect(p.x + 5, p.y + 2, 28, 22, main)
		rect(p.x + 8, p.y + 27, 8, 22, main); rect(p.x + 24, p.y + 27, 8, 22, main)
		rect(p.x + 15, p.y + 16, 8, 9, glow)
		draw_line(pos + Vector2(-26, -8), pos + Vector2(-38, 26), main, 8)
		draw_line(pos + Vector2(26, -8), pos + Vector2(38, 26), main, 8)
	else:
		# Guard and sentinel: readable shield, helm and weapon silhouettes.
		rect(p.x + 5, p.y + 15, 27, 31, dark)
		rect(p.x + 9, p.y + 5, 20, 20, main)
		rect(p.x + 13, p.y - 2, 12, 9, glow)
		rect(p.x - 5, p.y + 20, 13, 20, glow if kind == "sentinel" else dark)
		draw_line(pos + dir * 10 + Vector2(0, -16), pos + dir * 10 + dir * 35 + Vector2(0, -16), PAPER, 5)
		draw_line(pos + dir * 10 + Vector2(-8, -16), pos + dir * 10 + Vector2(8, -16), glow, 3)
	if enemy.state == "windup":
		draw_arc(pos, 57, dir.angle() - 1.0, dir.angle() + 1.0, 14, Color("f0a28d"), 2)
	if hit:
		draw_circle(pos + Vector2(0, -22), 28, Color("f5c66e", 0.22))

func draw_knight(pos: Vector2, direction: Vector2, evil: bool, walking: bool, flashing: bool, swinging: bool) -> void:
	var bob := sin(time * (13.0 if walking else 3.2) + pos.x * 0.03) * (3.0 if walking else 1.2)
	var recoil := sin(time * 44.0) * 3.0 if flashing else 0.0
	var p := pos.round() + Vector2(-16, -49 + bob) + direction * recoil
	var step_offset := sin(time * 17) * 4 if walking else 0.0
	if flashing:
		draw_circle(pos + Vector2(0, -20), 34 + sin(time * 38) * 4, Color("f5c66e", 0.22))
	var armor := Color("aebcd0") if not evil else Color("a47b86")
	var dark := Color("52647d") if not evil else Color("604655")
	var cloth := Color("56919a") if not evil else Color("b46659")
	if flashing:
		armor = PAPER
		cloth = PAPER
	if not evil and dash_left > 0:
		draw_line(pos - direction * 38, pos - direction * 10, GOLD, 7)
	if not evil:
		draw_arc(pos, 24, 0, TAU, 20, GOLD, 1)
	draw_ellipse_shadow(pos)
	rect(p.x + 3, p.y + 18, 24, 23, cloth)
	rect(p.x + 6, p.y + 35, 8, 12 + step_offset, dark)
	rect(p.x + 21, p.y + 35, 8, 12 - step_offset, dark)
	rect(p.x + 4, p.y + 44 + step_offset, 11, 5, armor)
	rect(p.x + 20, p.y + 44 - step_offset, 11, 5, armor)
	rect(p.x + 5, p.y + 20, 24, 15, dark)
	rect(p.x + 10, p.y + 21, 14, 10, armor)
	rect(p.x + 5, p.y + 3, 24, 17, armor)
	rect(p.x + 2, p.y + 8, 30, 7, armor)
	rect(p.x + 12, p.y - 2, 9, 7, cloth)
	if direction.y > -0.6:
		var side := 3 if direction.x >= 0 else -3
		rect(p.x + 9 + side, p.y + 10, 18, 5, INK)
		rect(p.x + 15 + side, p.y + 11, 5, 3, GOLD)
	else:
		rect(p.x + 13, p.y + 6, 6, 13, dark)
	rect(p.x - 5, p.y + 23, 15, 18, dark)
	rect(p.x - 2, p.y + 25, 9, 12, GOLD if not evil else cloth)
	var hand := pos + direction * 22 + Vector2(0, -19)
	var angle := direction.angle() + (-0.7 + (1 - slash_left / 0.2) * 1.4 if swinging and not evil else 0.0)
	var blade := Vector2.from_angle(angle)
	draw_line(hand, hand + blade * (43 if swinging else 30), PAPER if not evil else armor, 5)
	draw_line(hand - blade.orthogonal() * 7, hand + blade.orthogonal() * 7, GOLD, 4)

func draw_ellipse_shadow(pos: Vector2) -> void:
	rect(pos.x - 19, pos.y - 2, 38, 7, Color("171c2d"))

func capture_preview() -> void:
	await get_tree().create_timer(0.3).timeout
	paused = true
	queue_redraw()
	# Capture without overlay, frozen simulation.
	set_physics_process(false)
	paused = false
	queue_redraw()
	await RenderingServer.frame_post_draw
	var file := "user://action-preview.png"
	get_viewport().get_texture().get_image().save_png(file)
	print("ACTION_PREVIEW: ", ProjectSettings.globalize_path(file))
	get_tree().quit()
