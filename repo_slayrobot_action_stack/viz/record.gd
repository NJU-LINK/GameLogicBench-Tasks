extends Node2D
## record.gd — the viz/demo layer (geb "必交 but 降级": produces a readable mp4; the cross-check with
## the judge is informational, not a gate). It runs the SAME scenario the judge runs (level.gd +
## sim_core, with the delivered ActionHandler overlaid), so the rendered clip reflects the actual
## submission's behaviour, then draws what this task is actually about: the ORDER the scheduler ran
## things in, revealed one step at a time, against the contract-correct order underneath it, plus the
## scenario's numeric observations.
##
## The real Player / Enemy nodes are hidden — they are Control nodes parked at the origin in this
## light harness and would just overlap. What matters here is the schedule, not the sprites.

const Level := preload("res://level.gd")
const SimCore := preload("res://sim_core.gd")

const W := 1200.0
const H := 700.0
const FRAMES_INTRO := 24
const FRAMES_PER_STEP := 12
const FRAMES_OUTRO := 40

var _scenario := "baseline"
var _seed := 1
var _spec := {}
var _obs := {}
var _lists: Array = []      # [{key, got, want, ok}]
var _nums: Array = []       # [{key, got, want, ok, detail}]
var _steps := 0
var _frame := 0
var _total := 0
var _live := false
var _passed := false


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
		_scenario = "baseline"
		_spec = Level.build(_scenario, _seed)

	var world: Dictionary = SimCore.build_world(self, _spec)
	for k: String in ["player", "enemy"]:
		if world.has(k) and is_instance_valid(world[k]):
			world[k].visible = false
	_obs = await SimCore.run(self, world, _spec)

	_passed = true
	for chk: Dictionary in _spec["checks"]:
		var key: String = String(chk["key"])
		var got: Variant = _obs.get(key, null)
		var want: Variant = chk["expect"]
		var ok := false
		if String(chk["kind"]) == "list":
			ok = got is Array and str(got) == str(Array(want))
			_lists.append({"key": key, "got": got if got is Array else [], "want": want, "ok": ok})
			_steps = max(_steps, (got as Array).size() if got is Array else 0)
		elif String(chk["kind"]) == "int":
			ok = got != null and int(got) == int(want)
			_nums.append({"key": key, "got": str(got), "want": str(want), "ok": ok,
				"detail": String(chk.get("detail", ""))})
		else:
			ok = got != null and bool(got) == bool(want)
			_nums.append({"key": key, "got": str(got), "want": str(want), "ok": ok,
				"detail": String(chk.get("detail", ""))})
		_passed = _passed and ok

	_total = FRAMES_INTRO + FRAMES_PER_STEP * max(1, _steps) + FRAMES_OUTRO
	_live = true
	set_process(true)


func _process(_dt: float) -> void:
	if not _live:
		return
	_frame += 1
	queue_redraw()
	await get_tree().physics_frame   # gate frame emission for Movie Maker
	if _frame >= _total:
		await get_tree().create_timer(0.2).timeout
		print("GEB_RECORD ", JSON.stringify({"scenario": _scenario, "seed": _seed,
			"pass": _passed, "obs": _obs}))
		get_tree().quit(0 if _passed else 1)


func _revealed() -> int:
	var f := _frame - FRAMES_INTRO
	if f < 0:
		return 0
	return int(f / FRAMES_PER_STEP) + 1


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.10, 0.13))
	_text(Vector2(28, 40), "Slay the Robot — the action scheduler   [%s, seed %d]"
		% [_scenario, _seed], Color(0.86, 0.89, 0.96), 22)
	_text(Vector2(28, 68), "armed axis: %s" % String(_spec.get("armed", "-")),
		Color(0.55, 0.62, 0.72), 15)

	var n := _revealed()
	var y := 108.0
	for L: Dictionary in _lists:
		var got: Array = L["got"]
		draw_rect(Rect2(Vector2(24, y - 20), Vector2(W - 48, 62)), Color(0.14, 0.16, 0.20))
		_text(Vector2(36, y), String(L["key"]), Color(0.72, 0.78, 0.88), 15)
		var x := 300.0
		for i in got.size():
			var shown: bool = i < n
			var col := Color(0.55, 0.85, 0.6) if L["ok"] else Color(0.95, 0.6, 0.5)
			if not shown:
				col = Color(0.26, 0.28, 0.32)
			var s := "  %s  " % str(got[i])
			draw_rect(Rect2(Vector2(x, y - 15), Vector2(9.0 * s.length(), 22)), col.darkened(0.55))
			_text(Vector2(x + 4, y), s.strip_edges(), col, 15)
			x += 9.0 * s.length() + 8.0
		if not L["ok"]:
			_text(Vector2(300, y + 22), "contract: %s" % str(Array(L["want"])),
				Color(0.95, 0.82, 0.45), 13)
		else:
			_text(Vector2(300, y + 22), "matches the contract order", Color(0.45, 0.6, 0.5), 13)
		y += 74.0

	if _nums.size() > 0:
		y += 10.0
		_text(Vector2(36, y), "world numbers", Color(0.72, 0.78, 0.88), 16)
		y += 26.0
		for M: Dictionary in _nums:
			var col := Color(0.6, 0.85, 0.65) if M["ok"] else Color(0.95, 0.6, 0.5)
			var line := "%-18s %s   (contract %s)" % [String(M["key"]), String(M["got"]),
				String(M["want"])]
			_text(Vector2(48, y), line, col, 15)
			_text(Vector2(520, y), String(M["detail"]), Color(0.5, 0.56, 0.64), 13)
			y += 24.0

	var verdict := "PASS" if _passed else "FAIL"
	var vcol := Color(0.5, 0.9, 0.6) if _passed else Color(1.0, 0.5, 0.45)
	_text(Vector2(28, H - 34), "verdict: %s" % verdict, vcol, 22)


func _text(pos: Vector2, s: String, col: Color, sz: int) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
