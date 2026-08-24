extends "res://judge_core.gd"
## record.gd — the viz/demo layer (geb "必交 but 降级": produces a readable mp4; the cross-check with
## the judge is informational, not a gate). It extends the frozen judge driver, so the rendered run IS
## the judged combat: the same authored deck, the same frozen entry points, the same expectations.
##
## Nothing has to be drawn here. The deliverable under test IS the thing that fills the game's own
## combat screen — the hand of cards, the draw / discard / exhaust counters and the energy readout are
## the real UI, rendered by the real game while the delivered ledger drives it. Running the judge
## windowed is therefore the most faithful possible picture of what the submission does.


func _ready() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	# a real window is up, so let the combat screen be the visible root
	var result: Dictionary = await run(args)
	var out_path: String = String(args.get("out", ""))
	if out_path != "":
		var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(result, "  "))
			f.close()
	print("GEB_RECORD ", JSON.stringify(result))
	await get_tree().create_timer(0.4).timeout   # let Movie Maker flush its last frames
	get_tree().quit(0 if bool(result.get("pass", false)) else 1)


func _parse_args(uargs: PackedStringArray) -> Dictionary:
	var d: Dictionary = {}
	var i: int = 0
	while i < uargs.size():
		var a: String = uargs[i]
		if a.begins_with("--"):
			var key: String = a.substr(2)
			var val: String = "true"
			if i + 1 < uargs.size() and not uargs[i + 1].begins_with("--"):
				val = uargs[i + 1]
				i += 1
			d[key] = val
		i += 1
	return d
