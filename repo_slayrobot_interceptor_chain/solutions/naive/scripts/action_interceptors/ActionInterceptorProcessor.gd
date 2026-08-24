## NAIVE ActionInterceptorProcessor (geb red-team reference).
##
## A plausible-but-wrong completion. It makes the four mistakes the hollow invites:
##   (1) it pools EVERY interceptor registered on the parent or the target that intercepts this action,
##       ignoring the modifies_parent split (a target-side debuff on the attacker wrongly fires);
##   (2) it processes them in registration/gather order instead of sorting by descending priority;
##   (3) it clears the shadow layer before each interceptor, so every interceptor reads the ORIGINAL
##       action value instead of the running one and the final read is just the last write; and
##   (4) it treats a STOPPED interceptor as a rejection, dropping a chain that was accepted up to
##       the interceptor that asked the chain to end early.
## It also never reads the action's own assembly gate (ignored_interceptor_ids).
## Single-interceptor actions are unaffected, so the previewed combat clears.
extends Node
class_name ActionInterceptorProcessor

var parent_action: BaseAction = null
var target: BaseCombatant = null
var shadowed_action_values: Dictionary = {}

func _init(_parent_action: BaseAction, _target: BaseCombatant):
	parent_action = _parent_action
	target = _target

func process_interceptor_chain(preview_mode: bool = false) -> bool:
	for interceptor in _gather():
		shadowed_action_values.clear()   # (3) each interceptor sees the action's own values
		var result: int = interceptor.process_action_interception(self, preview_mode)
		if result == BaseActionInterceptor.ACTION_ACCEPTENCES.STOPPED:
			return false                 # (4) a stop ends the action, not just the chain
		if result == BaseActionInterceptor.ACTION_ACCEPTENCES.REJECTED:
			return false
	return true

func get_shadowed_action_values(key: String, default_value: Variant) -> Variant:
	var custom: Dictionary = parent_action.values.get("custom_key_names", {})
	var key_name: String = custom.get(key, key)
	if shadowed_action_values.has(key_name):
		return shadowed_action_values[key_name]
	return parent_action.get_action_value(key, default_value)

func set_shadowed_action_values(key: String, value: Variant) -> void:
	var custom: Dictionary = parent_action.values.get("custom_key_names", {})
	var key_name: String = custom.get(key, key)
	shadowed_action_values[key_name] = value

func _gather() -> Array[BaseActionInterceptor]:
	var out: Array[BaseActionInterceptor] = []
	var action_path: String = parent_action.get_script().resource_path
	var ids: Array = []
	ids.append_array(ActionHandler._registered_action_interceptor_object_ids.get(parent_action.parent_combatant, []))
	ids.append_array(ActionHandler._registered_action_interceptor_object_ids.get(target, []))
	for id: String in ids:
		var data: ActionInterceptorData = Global.get_action_interceptor_data(id)
		if data == null:
			continue
		if data.action_intercepted_action_paths.has(action_path):
			out.append(load(data.action_interceptor_script_path).new())
	return out
