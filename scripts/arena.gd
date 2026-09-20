extends Control
## Original procedural pixel art, isolated from the combat random generator.
var time := 0.0
var hero_alive := true
var enemy_alive := true
var shielded := false
var victory := false
var active_side := "hero"
var flash_side := ""
var flash_left := 0.0
var stars: Array[Vector2] = []
const NIGHT := Color("101323")
const DISTANT := Color("242940")
const STONE := Color("373c55")
const GOLD := Color("e5b969")
const PALE := Color("eee3cb")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky_rng := RandomNumberGenerator.new()
	sky_rng.seed = 142
	for i in range(45):
		stars.append(Vector2(sky_rng.randi_range(8, 552), sky_rng.randi_range(6, 93)))

func _process(delta: float) -> void:
	time += delta
	flash_left = maxf(0, flash_left - delta)
	queue_redraw()

func hit(side: String) -> void:
	flash_side = side
	flash_left = 0.23

func block(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(560, 180))
	block(0, 0, 560, 180, NIGHT)
	for point in stars:
		block(point.x, point.y, 1, 1, Color("77758b"))
	block(428, 18, 22, 22, Color("c2bbaa"))
	block(424, 16, 21, 18, NIGHT)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 121),Vector2(0, 98),Vector2(65, 58),Vector2(139, 108),Vector2(202, 63),Vector2(280, 117),Vector2(365, 69),Vector2(422, 107),Vector2(500, 62),Vector2(560, 103),Vector2(560, 130)]), DISTANT)
	# The unlit tower behind the arena.
	block(244, 37, 72, 102, Color("1b2035"))
	block(239, 34, 82, 12, STONE)
	for x in range(242, 319, 16):
		block(x, 25, 9, 12, STONE)
	block(267, 63, 25, 69, NIGHT)
	block(273, 56, 13, 76, NIGHT)
	for y in range(51, 133, 17):
		block(245, y, 17, 2, DISTANT)
		block(301, y + 6, 14, 2, DISTANT)
	if victory:
		block(273, 66, 13, 54, GOLD)
		block(277, 70, 5, 49, PALE)
	# Stone walkway and braziers.
	block(0, 139, 560, 5, Color("626278"))
	block(0, 144, 560, 36, Color("292c41"))
	for x in range(0, 560, 40):
		block(x, 145, 1, 15, NIGHT)
		block(x + 20, 163, 1, 17, NIGHT)
	block(0, 160, 560, 2, NIGHT)
	for x in [67, 484]:
		block(x, 117, 9, 21, STONE)
		block(x - 3, 111, 15, 6, Color("9c7857"))
		var flicker := int(time * 6) % 3
		block(x, 102 - flicker, 8, 10 + flicker, Color("d7774d"))
		block(x + 3, 99 + flicker, 4, 11 - flicker, GOLD)
	if hero_alive:
		draw_knight(Vector2(159, 91), false)
	else:
		block(153, 130, 34, 8, STONE)
	if enemy_alive:
		draw_knight(Vector2(370, 87), true)
	else:
		block(362, 130, 35, 8, Color("675067"))
	if not victory and hero_alive and enemy_alive:
		var x := 171 if active_side == "hero" else 382
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 77),Vector2(x + 4, 77),Vector2(x, 82)]), GOLD)

func draw_knight(origin: Vector2, evil: bool) -> void:
	var side := "enemy" if evil else "hero"
	var p := origin + Vector2(0, int(sin(time * 2.6)) if evil else int(sin(time * 2.3)))
	var armor := Color("9ba6b4") if not evil else Color("866377")
	var dark := Color("515f77") if not evil else Color("493748")
	var cloth := Color("577d91") if not evil else Color("b66155")
	if flash_left > 0 and flash_side == side:
		armor = PALE
		cloth = PALE
	# 16x24 sprite on a 2-pixel grid.
	block(p.x - 8, 137, 43, 2, NIGHT)
	block(p.x - 2, p.y + 17, 9, 24, cloth)
	block(p.x + 4, p.y + 4, 20, 16, armor)
	block(p.x + 2, p.y + 8, 24, 6, armor)
	block(p.x + 8, p.y + 11, 16, 4, NIGHT)
	block(p.x + 18, p.y + 11, 4, 3, Color("eaa46b") if evil else GOLD)
	block(p.x + 9, p.y, 8, 5, cloth)
	block(p.x + 3, p.y + 21, 23, 14, dark)
	block(p.x + 8, p.y + 21, 12, 10, armor)
	block(p.x + 3, p.y + 35, 8, 12, dark)
	block(p.x + 18, p.y + 35, 8, 12, dark)
	block(p.x + 1, p.y + 44, 11, 4, armor)
	block(p.x + 17, p.y + 44, 12, 4, armor)
	# Sword and shield.
	block(p.x + 31, p.y + 9, 3, 25, armor)
	block(p.x + 27, p.y + 30, 11, 3, GOLD)
	block(p.x + 31, p.y + 33, 3, 7, dark)
	block(p.x - 7, p.y + 22, 15, 18, GOLD if shielded and not evil else dark)
	block(p.x - 4, p.y + 25, 9, 10, cloth)
	if shielded and not evil:
		draw_rect(Rect2(p.x - 13, p.y - 6, 55, 58), GOLD, false, 1)
