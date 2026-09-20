extends RefCounted
## Pure battle model: no scene tree, UI, timers or global random state.
## Same version + seed + actions => identical battle. World generation comes later.

const RULESET := "combat-v0.1"
const SHIELD_COST := 4
const EXECUTE_COST := 6
var rng := RandomNumberGenerator.new()
var hero: Dictionary
var enemy: Dictionary
var seed_text := "DAWN-47X9"
var actor := "hero"
var first_actor := "hero"
var round_number := 1
var enemy_actions := 0
var shield_hits := 0
var finished := false
var won := false
var history: Array[String] = []

func reset(value: String, hero_spd: int = 10, enemy_spd: int = 8) -> void:
	seed_text = value.strip_edges().to_upper()
	if seed_text.is_empty():
		seed_text = "DAWN-47X9"
	rng.seed = (RULESET + ":" + seed_text).sha256_text().substr(0, 8).hex_to_int()
	hero = {"name": "Рыцарь Зари", "hp": 100, "max_hp": 100, "mp": 18, "max_mp": 18, "atk": 18, "def": 10, "spd": hero_spd, "res": 6}
	enemy = {"name": "Пепельный страж", "hp": 86, "max_hp": 86, "mp": 0, "max_mp": 0, "atk": 18, "def": 8, "spd": enemy_spd, "res": 4}
	first_actor = "hero" if hero_spd >= enemy_spd else "enemy"
	actor = first_actor
	round_number = 1
	enemy_actions = 0
	shield_hits = 0
	finished = false
	won = false
	history.clear()
	history.append("Башня Пепла. Страж преграждает путь к огню Зари.")
	history.append("Инициатива по SPD: первым ходит %s." % (hero.name if actor == "hero" else enemy.name))

static func base_damage(atk: int, multiplier: float, defense: int) -> int:
	return maxi(1, roundi(maxf(1.0, atk * multiplier - defense * 0.5)))

func can_act(action: String) -> bool:
	if finished or actor != "hero":
		return false
	match action:
		"attack": return true
		"shield": return hero.mp >= SHIELD_COST
		"execute": return hero.mp >= EXECUTE_COST
	return false

func act(action: String) -> bool:
	if not can_act(action):
		return false
	match action:
		"attack":
			strike(hero, enemy, 1.0, "Удар мечом")
		"shield":
			hero.mp -= SHIELD_COST
			shield_hits = 2
			history.append("Щит веры: +12 DEF на следующие 2 атаки врага. −4 MP.")
		"execute":
			hero.mp -= EXECUTE_COST
			if enemy.hp * 5 < enemy.max_hp:
				enemy.hp = 0
				history.append("Казнь: враг ниже 20% HP. Страж повержен. −6 MP.")
			else:
				strike(hero, enemy, 1.6, "Казнь (−6 MP)")
	advance()
	return true

func enemy_act() -> bool:
	if finished or actor != "enemy":
		return false
	enemy_actions += 1
	var heavy := enemy_actions % 3 == 0
	strike(enemy, hero, 1.6 if heavy else 1.0, "Сокрушение" if heavy else "Удар стража", 12 if shield_hits > 0 else 0)
	if shield_hits > 0:
		shield_hits -= 1
	advance()
	return true

func strike(source: Dictionary, target: Dictionary, multiplier: float, title: String, bonus_def: int = 0) -> void:
	if rng.randf() < 0.05:
		history.append("%s: промах." % title)
		return
	var critical := rng.randf() < 0.10
	var amount := base_damage(source.atk, multiplier, target.def + bonus_def)
	if critical:
		amount = roundi(amount * 1.5)
	target.hp = maxi(0, target.hp - amount)
	history.append("%s: %d урона%s." % [title, amount, " · КРИТ" if critical else ""])

func advance() -> void:
	if hero.hp <= 0 or enemy.hp <= 0:
		finished = true
		won = enemy.hp <= 0
		history.append("ПОБЕДА. Огонь первой башни зажжён." if won else "ПОРАЖЕНИЕ. Заря ждёт следующей попытки.")
		return
	actor = "enemy" if actor == "hero" else "hero"
	if actor == first_actor:
		round_number += 1

func intent() -> String:
	if finished:
		return "Страж повержен" if won else "Башня осталась во тьме"
	return "СОКРУШЕНИЕ · 1.6× урона" if (enemy_actions + 1) % 3 == 0 else "Удар мечом · 1× урона"
