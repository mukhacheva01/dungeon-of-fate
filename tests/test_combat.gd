extends SceneTree
const Combat = preload("res://scripts/combat.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func simulate(seed_value: String) -> Array[String]:
	var c = Combat.new()
	c.reset(seed_value)
	for i in range(300):
		if c.finished:
			break
		if c.actor == "enemy":
			c.enemy_act()
		elif c.hero.mp >= 6 and c.enemy.hp < 30:
			c.act("execute")
		else:
			c.act("attack")
	check(c.finished, "Battle terminates for " + seed_value)
	check(c.hero.hp >= 0 and c.enemy.hp >= 0, "HP never negative")
	check(c.hero.mp >= 0, "MP never negative")
	return c.history.duplicate()

func _initialize() -> void:
	check(Combat.base_damage(18, 1.0, 8) == 14, "Damage formula")
	check(Combat.base_damage(18, 1.6, 8) == 25, "Skill damage rounded")
	check(Combat.base_damage(1, 1.0, 100) == 1, "Minimum damage")
	var c = Combat.new()
	c.reset(" dawn-47x9 ")
	check(c.seed_text == "DAWN-47X9", "Seed normalization")
	check(c.hero.hp == 100 and c.hero.mp == 18, "Initial resources")
	check(c.actor == "hero", "Faster hero first")
	c.reset("test", 4, 9)
	check(c.actor == "enemy", "Faster enemy first")
	check(not c.act("attack"), "Cannot act out of turn")
	c.enemy_act()
	check(c.actor == "hero" and c.round_number == 1, "Enemy-first order")
	c.act("attack")
	check(c.actor == "enemy" and c.round_number == 2, "SPD round rotation")
	c.reset("test", 8, 8)
	check(c.actor == "hero", "Stable tie break")
	check(not c.act("unknown"), "Reject invalid action")
	check(c.act("shield"), "Shield accepted")
	check(c.hero.mp == 14 and c.shield_hits == 2, "Shield resources")
	check(not c.act("attack"), "Double input rejected")
	c.enemy_act()
	check(c.shield_hits == 1, "Shield consumes one enemy attack")
	c.act("attack")
	c.enemy_act()
	check(c.shield_hits == 0, "Shield expires after two enemy attacks")
	check(c.intent().contains("1.6"), "Heavy attack is telegraphed")
	c.reset("execute")
	c.enemy.hp = 17
	c.act("execute")
	check(c.finished and c.won and c.enemy.hp == 0, "Execute below twenty percent")
	check(c.hero.mp == 12, "Execute MP cost")
	check(not c.enemy_act() and not c.act("attack"), "Finished battle locked")
	c.reset("boundary")
	c.enemy.max_hp = 100
	c.enemy.hp = 20
	c.enemy.def = 1000
	c.act("execute")
	check(not c.finished, "Exactly twenty percent is not guaranteed execute")
	c.reset("mana")
	c.hero.mp = 3
	var state_before: int = c.rng.state
	check(not c.act("shield") and not c.act("execute"), "Reject insufficient mana")
	check(c.actor == "hero" and c.hero.mp == 3 and c.rng.state == state_before, "Invalid action changes nothing")
	c.reset("death")
	c.hero.hp = 1
	c.enemy.atk = 10000
	c.actor = "enemy"
	for i in range(20):
		if c.finished:
			break
		c.actor = "enemy"
		c.enemy_act()
	check(c.finished and not c.won and c.hero.hp == 0, "Defeat")
	c.reset("")
	check(not c.finished and c.round_number == 1 and c.enemy_actions == 0 and c.shield_hits == 0, "Reset clears all battle state")
	check(c.seed_text == "DAWN-47X9", "Empty seed fallback")
	check(simulate("DAWN-47X9") == simulate("DAWN-47X9"), "Same seed and actions reproduce battle")
	check(simulate("DAWN-47X9") != simulate("DAWN-OTHER"), "Different seeds change combat outcomes")
	for i in range(100):
		simulate("TEST-%d" % i)
	print("COMBAT TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
