extends SceneTree
var checks := 0
var failures := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ACTION: ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var battle = load("res://scenes/action_battle.tscn").instantiate()
	root.add_child(battle)
	battle.set_physics_process(false)
	await process_frame
	battle.start_run()
	check(battle.started and battle.hp == 100 and battle.max_hp == 100 and battle.living_enemies() == 3, "Initial state")
	battle.boosts.clear(); battle.boosts.append("vitality")
	battle.level = 2
	battle.begin_level()
	check(battle.max_hp == 120 and battle.hp == 120, "Vitality increases current and max HP")
	battle.boosts.clear(); battle.boosts.append("blade")
	battle.enemies.clear()
	battle.enemies.append(battle.make_enemy(Vector2(560, 510), "test", 100, 0, "guard"))
	battle.player = Vector2(560, 565); battle.facing = Vector2.UP; battle.slash_cd = 0
	battle.attack()
	check(battle.enemies[0].hp <= 70, "Blade boost increases damage")
	battle.boosts.clear(); battle.boosts.append("dash"); battle.dash_cd = 0; battle.step(0.01, Vector2.ZERO, false, true); check(battle.dash_cd < 1.0, "Dash boost reduces cooldown")
	battle.restart(); battle.start_run(); battle.boosts.append("armor"); battle.invulnerable = 0; battle.damage_player(14); check(battle.hp == 90, "Armor boost reduces incoming damage")
	battle.boosts.clear(); battle.boosts.append("flame"); battle.enemies.clear(); battle.enemies.append(battle.make_enemy(Vector2(560, 510), "test", 100, 0, "guard")); battle.player = Vector2(560, 565); battle.facing = Vector2.UP; battle.slash_cd = 0; battle.attack(); check(battle.enemies[0].hp <= 70, "Flame boost increases hit damage")
	battle.boosts.clear(); battle.boosts.append("frost"); battle.restart(); battle.start_run(); battle.enemies[0].pos = Vector2(100, 300); battle.player = Vector2(900, 500); var before_frost: Vector2 = battle.enemies[0].pos; battle.step(0.1, Vector2.ZERO); var frost_distance: float = battle.enemies[0].pos.distance_to(before_frost); check(frost_distance < 8, "Frost boost slows enemies")
	battle.restart(); battle.start_run(); battle.boosts.append("haste"); var before_haste: Vector2 = battle.player; battle.step(0.1, Vector2.RIGHT); check(battle.player.x - before_haste.x > 22, "Haste boost increases movement")
	check(battle.boost_title("vitality").contains("+20 HP"), "Every boost has a readable title")
	battle.restart(); battle.start_run()
	for enemy in battle.enemies:
		check(enemy.pos.y >= 245 and enemy.pos.y <= 610, "Enemy spawn stays inside arena")
		check(enemy.has("kind") and enemy.kind in ["guard", "sentinel", "archer", "mage", "golem", "shade"], "Enemy has a pixel-art kind")
	battle.level = 10
	battle.begin_level()
	check(battle.enemies[0].kind == "dragon", "Dragon has dedicated sprite set")
	battle.enemies.clear()
	var start: Vector2 = battle.player
	battle.step(0.1, Vector2.RIGHT)
	check(is_equal_approx(battle.player.x - start.x, 22.0), "Movement speed")
	battle.player = start
	battle.step(0.1, Vector2(1, 1))
	check(is_equal_approx(battle.player.distance_to(start), 22.0), "Diagonal normalization")
	battle.player = Vector2(100, 500)
	battle.step(1, Vector2.LEFT)
	check(battle.player.x >= 62, "World boundary")
	battle.player = Vector2(180, 340)
	battle.facing = Vector2.RIGHT
	battle.step(0.1, Vector2.RIGHT, false, true)
	check(battle.player.x < 223, "Dash does not tunnel through pillar")
	check(battle.dash_cd > 0 and battle.invulnerable > 0, "Dash cooldown and invulnerability")
	battle.damage_player(14)
	check(battle.hp == 100, "Dash evades damage")
	battle.invulnerable = 0
	battle.damage_player(14)
	check(battle.hp == 86, "Contact strike damage")
	battle.damage_player(14)
	check(battle.hp == 86, "I-frames prevent stacked damage")
	battle.restart()
	battle.enemies.assign([battle.make_enemy(Vector2(560, 510), "front", 56, 0), battle.make_enemy(Vector2(560, 620), "behind", 56, 0), battle.make_enemy(Vector2(900, 510), "far", 56, 0)])
	check(battle.attack(), "Attack accepted")
	check(battle.enemies[0].hp == 34, "Sword hits nearby enemy in facing cone")
	check(battle.enemies[1].hp == 56, "Sword does not hit behind")
	check(battle.enemies[2].hp == 56, "Sword range enforced")
	check(not battle.attack() and battle.enemies[0].hp == 34, "One damage per swing and cooldown")
	battle.slash_cd = 0
	battle.player = Vector2(210, 335)
	battle.facing = Vector2.RIGHT
	battle.enemies.assign([battle.make_enemy(Vector2(288, 335), "behind wall", 56, 0)])
	battle.attack()
	check(battle.enemies[0].hp == 56, "Sword cannot hit through wall")
	battle.restart()
	battle.enemies.assign([battle.make_enemy(Vector2(560, 515), "test", 56, 0)])
	battle.step(0.01, Vector2.ZERO)
	check(battle.enemies[0].state == "windup" and battle.hp == 100, "Enemy telegraphs without instant damage")
	battle.step(0.3, Vector2.ZERO)
	check(battle.hp == 100, "Windup grants dodge time")
	battle.step(0.36, Vector2.ZERO)
	check(battle.hp == 86 and battle.enemies[0].state == "recover", "Enemy strikes after windup")
	battle.restart()
	battle.enemies.assign([battle.make_enemy(Vector2(560, 515), "test", 56, 0)])
	battle.step(0.01, Vector2.ZERO)
	battle.player = Vector2(760, 565)
	battle.step(0.7, Vector2.ZERO)
	check(battle.hp == 100, "Move out of telegraph to avoid hit")
	battle.paused = true
	start = battle.player
	var clock: float = battle.elapsed
	battle.step(1, Vector2.RIGHT, true, true)
	check(battle.player == start and battle.elapsed == clock, "Pause freezes simulation")
	check(not battle.attack(), "Pause prevents mouse attack")
	battle.restart()
	battle.enemies.clear()
	battle.player = battle.PORTAL + Vector2(0, 26)
	battle.step(0.01, Vector2.ZERO)
	check(battle.choosing_boost and not battle.finished, "Cleared tower opens boost choice")
	check(battle.boost_choices.size() == 3 and battle.buttons.boost1.visible, "Three boost choices visible")
	battle.select_boost(0)
	check(battle.level == 2 and not battle.choosing_boost and battle.living_enemies() >= 3, "Boost advances to next level")
	battle.restart()
	battle.level = 10
	battle.begin_level()
	check(battle.dragon and battle.enemies.size() == 1 and battle.enemies[0].max_hp > 300, "Level ten dragon")
	battle.enemies.clear()
	battle.player = battle.PORTAL + Vector2(0, 26)
	battle.step(0.01, Vector2.ZERO)
	check(battle.finished and battle.won, "Final level wins after dragon")
	check(not battle.attack(), "Finished battle locked")
	battle.restart()
	battle.damage_player(1000)
	check(battle.finished and not battle.won and battle.hp == 0, "Defeat and HP floor")
	battle.restart()
	check(not battle.finished and battle.hp == 100 and battle.strikes == 0 and battle.living_enemies() == 3, "Restart resets all state")
	battle.focus_lost()
	check(battle.paused, "Auto pause on focus loss")
	battle.toggle_pause()
	check(not battle.paused, "Resume")
	battle.size = Vector2(800, 600)
	battle.layout_buttons()
	check(battle.ui_scale > 0 and battle.buttons.attack.position.x < 800, "Buttons fit resized window")
	# Physical key events must work independently of keyboard language.
	var press := InputEventKey.new()
	press.physical_keycode = KEY_D
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	battle.enemies.clear()
	battle.player = Vector2(560, 565)
	battle._physics_process(0.1)
	check(battle.player.x > 560, "Physical D input moves hero")
	press = InputEventKey.new()
	press.physical_keycode = KEY_D
	press.pressed = false
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	battle.queue_free()
	await process_frame
	print("ACTION TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
