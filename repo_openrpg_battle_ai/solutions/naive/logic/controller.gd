extends RefCounted
## NAIVE reference controller (red team): a plausible whole attempt. It reads the LIVE roster on every
## call and plans the party's round in the engine's emergent speed order, and it does try to spread the
## party's fire instead of dogpiling. Three things it gets wrong:
##
##  1. Its anticipation is only ONE DEEP and keeps no damage ledger. It remembers just the target the
##     PREVIOUS ally in the order was handed and steers off that one, re-reading everyone else's LIVE
##     hp -- which is still the pre-round hp, because nothing has executed yet. With a two-member party
##     "the previous one" is the whole history and it looks correct; from the third member on it hands
##     out a target an earlier, faster ally is already going to kill, and the engine binds
##     cached_targets[0] with no liveness recheck (battler_action_attack.execute) -- so the slow member
##     swings at a corpse.
##  2. It treats every live enemy as an equal body, so targeting collapses to "closest to dying". A
##     stats action (battler_action_modify_stats) is a PERMANENT, never-expiring debuff, so the enemy
##     carrying one compounds while the party farms the frail ones.
##  3. It always fires the heaviest action it can currently afford. energy only ever decreases
##     (battler.act subtracts it, nothing restores it), so the one-time costed strike gets burnt on a
##     target a free strike already one-shots.


func select_action(battler) -> void:
	var roster = _roster(battler)
	if roster == null:
		return
	var plan := _plan_round(roster)
	if plan.has(battler):
		var choice = plan[battler]
		_cache(battler, choice["action"], choice["target"])


func _roster(battler):
	for a in battler.actions:
		if a.battler_roster != null:
			return a.battler_roster
	return battler.get_parent()


# Plan the whole party's round from the current live state.
func _plan_round(roster) -> Dictionary:
	var allies: Array = roster.find_live_battlers(roster.get_player_battlers())
	allies.sort_custom(func(a, b): return a.stats.speed > b.stats.speed)
	var enemies: Array = roster.find_live_battlers(roster.get_enemy_battlers())

	var plan := {}
	# DEFECT 1: one-deep memory instead of a ledger of the damage already booked this round.
	var last_target = null
	for ally in allies:
		var target = _pick_target(enemies, last_target)
		if target == null:
			continue
		plan[ally] = {"action": _choose_action(ally), "target": target}
		last_target = target
	return plan


# The live enemy closest to dying, skipping only the one the previous ally was handed.
func _pick_target(enemies: Array, last_target):
	var live: Array = enemies.filter(func(e): return int(e.stats.health) > 0 and e != last_target)
	if live.is_empty():
		return null
	live.sort_custom(func(a, b):
		var ta := _threat(a)
		var tb := _threat(b)
		if ta != tb:
			return ta > tb
		return int(a.stats.health) < int(b.stats.health))
	return live[0]


func _threat(_enemy) -> int:
	return 1   # DEFECT 2: a permanent debuffer ranks as a plain body


# The heaviest action this ally can currently afford, whatever the target actually needs.
func _choose_action(ally):
	var strike := -1
	var heavy := -1
	for i in range(ally.actions.size()):
		var a = ally.actions[i]
		if not _is_attack(a):
			continue
		if int(a.energy_cost) == 0:
			if strike == -1:
				strike = i
		else:
			if int(ally.stats.energy) >= int(a.energy_cost) and (heavy == -1 or _nominal_damage(ally, i) > _nominal_damage(ally, heavy)):
				heavy = i
	# DEFECT 3: no "a free strike already finishes it" check -- the one-time budget is spent anyway.
	if heavy != -1:
		return heavy
	return strike if strike != -1 else 0


func _is_attack(a) -> bool:
	var s = a.get_script()
	return s != null and String(s.resource_path).ends_with("battler_action_attack.gd")


func _nominal_damage(ally, action_index: int) -> int:
	var a = ally.actions[action_index]
	if not _is_attack(a):
		return 0
	return int(a.base_damage) + int(ally.stats.attack)


func _cache(battler, action_index: int, target) -> void:
	var proto = battler.actions[action_index]
	var action = proto.duplicate()
	action.source = battler
	action.battler_roster = proto.battler_roster
	var targets: Array[Battler] = []
	targets.append(target)
	action.cached_targets = targets
	battler.cached_action = action
