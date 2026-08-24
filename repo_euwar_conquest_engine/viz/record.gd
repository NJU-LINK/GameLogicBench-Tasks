extends "res://judge.gd"
#
# viz/record.gd -- thin recording shell over the frozen judge driver. The
# rendered run IS the judged simulation: same world construction, same round
# loop, same assertions. On every strategic round it refreshes the game's own
# conquest map scene (the real EU-War strategic board: territory markers,
# owner colours, supply links, fortify pips, the HUD) and holds a couple of
# dozen movie frames so the round-by-round expansion is readable on video.

var _map: Node2D = null


func _init() -> void:
	_record_mode = true
	_record_hold = 30


func _on_frame(_vs: Dictionary) -> void:
	if _map == null:
		_map = load("res://scenes/conquest_map.tscn").instantiate()
		get_tree().root.add_child.call_deferred(_map)
		return
	if is_instance_valid(_map):
		_map._refresh()
