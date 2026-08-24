extends Node2D
## record.gd — the viz/demo layer (geb "必交 but 降级": produces a readable mp4; cross-check with the
## judge is informational, not a gate). It runs the SAME battle the judge drives (level.gd + sim_core
## with the overlaid ActionInterceptorProcessor) so the rendered run reflects the actual solution's
## behaviour, then animates the resulting attack trace as a compact vector view — attacker + target
## panels, health bars, active statuses, and a per-attack damage callout — stretched over enough
## engine frames for Godot Movie Maker to capture a watchable clip.

const Level := preload("res://level.gd")
const SimCore := preload("res://sim_core.gd")

const W := 640.0
const H := 480.0
const FRAMES_INTRO := 30
const FRAMES_PER_ATTACK := 48

var _scenario := "baseline"
var _seed := 1
var _spec := {}
var _trace: Array = []
var _enemy_hp_start := 0
var _enemy_hp_max := 0
var _frame := 0
var _total := 0
var _ready_done := false


func _ready() -> void:
	var uargs := OS.get_cmdline_user_args()
	for i in uargs.size():
		if uargs[i] == "--scenario" and i + 1 < uargs.size():
			_scenario = uargs[i + 1]
		elif uargs[i] == "--seed" and i + 1 < uargs.size():
			_seed = int(uargs[i + 1])

	await get_tree().process_frame
	_spec = Level.build(_scenario, _seed)
	if _spec.is_empty():
		_spec = Level.build("baseline", _seed)
		_scenario = "baseline"
	_enemy_hp_start = int(_spec["enemy"]["hp"])
	_enemy_hp_max = _enemy_hp_start

	var world: Dictionary = SimCore.build_world(self, _spec)
	# combatants are real Control nodes added to the tree; hide them, we draw our own clean view.
	if world.has("player") and is_instance_valid(world["player"]):
		world["player"].visible = false
	if world.has("enemy") and is_instance_valid(world["enemy"]):
		world["enemy"].visible = false
	var result: Dictionary = await SimCore.run(self, world, _spec)
	_trace = result["attacks"]

	_total = FRAMES_INTRO + FRAMES_PER_ATTACK * max(1, _trace.size()) + FRAMES_INTRO
	_ready_done = true
	set_process(true)


func _process(_dt: float) -> void:
	if not _ready_done:
		return
	_frame += 1
	queue_redraw()
	await get_tree().physics_frame  # gate frame emission for Movie Maker
	if _frame >= _total:
		await get_tree().create_timer(0.2).timeout  # let Movie Maker flush
		get_tree().quit(0)


# how many attacks have fully resolved by the current frame, and the interpolation within the current
func _progress() -> Array:
	var f := _frame - FRAMES_INTRO
	if f < 0:
		return [0, 0.0]
	var done := int(f / FRAMES_PER_ATTACK)
	var within := float(f % FRAMES_PER_ATTACK) / float(FRAMES_PER_ATTACK)
	return [min(done, _trace.size()), clampf(within, 0.0, 1.0)]


func _current_enemy_hp() -> float:
	var pr := _progress()
	var done: int = pr[0]
	var within: float = pr[1]
	var hp := float(_enemy_hp_start)
	for i in range(min(done, _trace.size())):
		hp = float(_trace[i]["hp_after"])
	if done < _trace.size():
		var a: Dictionary = _trace[done]
		hp = lerpf(float(a["hp_before"]), float(a["hp_after"]), within)
	return hp


func _draw() -> void:
	# background
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.10, 0.13))
	var title := "Slay the Robot - interceptor chain  [%s, seed %d]" % [_scenario, _seed]
	_text(Vector2(16, 28), title, Color(0.85, 0.88, 0.95), 16)

	# attacker panel (left)
	_panel(Vector2(24, 70), "ATTACKER", _spec.get("player", {}), Color(0.35, 0.6, 0.95),
		float(int(_spec.get("player", {}).get("hp", 100))), float(int(_spec.get("player", {}).get("hp", 100))))
	# target panel (right)
	_panel(Vector2(344, 70), "TARGET (enemy)", _spec.get("enemy", {}), Color(0.95, 0.45, 0.4),
		_current_enemy_hp(), float(_enemy_hp_max))

	# attack callout
	var pr := _progress()
	var done: int = pr[0]
	var idx: int = min(done, _trace.size() - 1) if _trace.size() > 0 else -1
	if idx >= 0 and _frame >= FRAMES_INTRO:
		var a: Dictionary = _trace[idx]
		var msg := "attack %d:  base %d  ->  enemy lost %d hp   (block %d -> %d)" % [
			idx + 1, int(a["damage"]), int(a["hp_loss"]), int(a["block_before"]), int(a["block_after"])]
		_text(Vector2(24, 300), msg, Color(1, 0.9, 0.5), 15)
	# resolved log
	var y := 330.0
	for i in range(min(done, _trace.size())):
		var a: Dictionary = _trace[i]
		_text(Vector2(24, y), "  #%d  -%d hp" % [i + 1, int(a["hp_loss"])], Color(0.7, 0.75, 0.8), 13)
		y += 20


func _panel(pos: Vector2, label: String, spec: Dictionary, col: Color, hp: float, hp_max: float) -> void:
	var size := Vector2(272, 200)
	draw_rect(Rect2(pos, size), Color(0.15, 0.17, 0.21))
	draw_rect(Rect2(pos, Vector2(size.x, 26)), col.darkened(0.2))
	_text(pos + Vector2(10, 19), label, Color.WHITE, 14)
	# hp bar
	var bar_pos := pos + Vector2(12, 44)
	var bar_size := Vector2(size.x - 24, 22)
	draw_rect(Rect2(bar_pos, bar_size), Color(0.08, 0.08, 0.1))
	var frac := clampf(hp / max(1.0, hp_max), 0.0, 1.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_size.x * frac, bar_size.y)), col)
	_text(bar_pos + Vector2(8, 16), "HP %d / %d" % [int(round(hp)), int(hp_max)], Color.WHITE, 13)
	# statuses
	var y := bar_pos.y + 40
	_text(pos + Vector2(12, y - 6), "statuses:", Color(0.7, 0.75, 0.82), 13)
	y += 16
	for st: Array in spec.get("statuses", []):
		_text(pos + Vector2(20, y), "- %s x%d" % [String(st[0]).replace("status_effect_", ""), int(st[1])],
			Color(0.8, 0.85, 0.7), 12)
		y += 18
	var blk := int(spec.get("block", 0))
	if blk > 0:
		_text(pos + Vector2(20, y), "- block %d" % blk, Color(0.6, 0.8, 0.95), 12)


func _text(pos: Vector2, s: String, col: Color, sz: int) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
