extends SceneTree
var failures := 0
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL UI: ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.combat.actor == "hero", "Starts on player's turn")
	check(not scene.action_buttons.attack.disabled, "Attack button enabled")
	scene.player_action("shield")
	check(scene.combat.hero.mp == 14, "Button invokes model")
	check(scene.action_buttons.attack.disabled, "Buttons locked during enemy timer")
	scene.restart()
	await create_timer(0.9).timeout
	check(scene.combat.hero.hp == 100 and scene.combat.enemy_actions == 0, "Restart cancels stale enemy timer")
	scene.player_action("attack")
	await create_timer(0.9).timeout
	check(scene.combat.enemy_actions == 1 and scene.combat.actor == "hero", "Enemy takes exactly one turn")
	check(not scene.action_buttons.attack.disabled, "Buttons unlock")
	scene.size = Vector2(600, 820)
	scene.responsive()
	check(scene.actions.columns == 1 and scene.stats_row.vertical, "Narrow layout stacks controls")
	scene.combat.hero.mp = 0
	scene.refresh()
	check(scene.action_buttons.shield.disabled and scene.action_buttons.execute.disabled, "Unaffordable actions disabled")
	check(not scene.action_buttons.attack.disabled, "Free attack stays enabled")
	scene.combat.finished = true
	scene.combat.won = false
	scene.refresh()
	check(scene.action_buttons.attack.disabled, "Defeat locks actions")
	check(not scene.result_label.text.is_empty(), "Result visible")
	print("UI TESTS: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
