class_name PipeHeatDistributor
extends Node2D
# NAIVE (single defect, heat_conservation family): the nearest-upstream restriction is gone -- a
# receiver is attached to EVERY provider known so far, so once a pipe run carries more than one
# provider the per-provider attribution arithmetic double-counts. Where a run has a single provider
# there is nothing to double-attach and it behaves correctly.

var _heat_receivers = {}
var _heat_providers = {}

var _paths: PipePaths

@onready var _visualizer: PipeHeatNumberVisualizer = $PipeHeatNumberVisualizer

var _queue_repathing := false
var _heat_connections := {}  # Position of provider to receiver list


func _init():
	Events.entity_placed.connect(_on_entity_placed)
	Events.entity_removed.connect(_on_entity_removed)
	Events.system_tick.connect(_on_system_tick)


func setup(paths: PipePaths) -> void:
	_paths = paths
	_paths.paths_changed.connect(_on_paths_changed)


func _on_entity_placed(entity: Entity, cellv: Vector2):
	if entity.is_in_group(Types.HEAT_PROVIDER):
		_heat_providers[cellv] = entity.get_node_or_null("HeatProvider")
		_queue_repathing = true

	if entity.is_in_group(Types.HEAT_RECEIVER):
		_heat_receivers[cellv] = entity.get_node_or_null("HeatReceiver")
		_queue_repathing = true


func _on_entity_removed(_entity: Entity, cellv: Vector2):
	if _heat_receivers.erase(cellv):
		_queue_repathing = true

	if _heat_providers.erase(cellv):
		_queue_repathing = true


func _on_paths_changed():
	_queue_repathing = true


func _on_system_tick(_delta):
	if _queue_repathing:
		_repath()
		_queue_repathing = false

	_distribute_heat()


func _distribute_heat() -> void:
	for provider_pos in _heat_connections.keys():
		var heat_used = 0
		var provider = _heat_providers[provider_pos] as HeatProvider
		var receiver_count = len(_heat_connections[provider_pos])

		for receiver_pos in _heat_connections[provider_pos]:
			var receiver: HeatReceiver = _heat_receivers[receiver_pos]
			var heat_provided: int = min(
				receiver.required_heat, float(provider.amount) / receiver_count
			)

			heat_used += heat_provided
			receiver.matieral_provided.emit(heat_provided)

			if not receiver_pos in _heat_providers:
				_visualizer.add_number(heat_provided, receiver.global_position + Vector2(0, 6))

		provider.amount -= heat_used
		provider.amount = max(0, provider.amount)

		# _visualizer.add_number(-heat_used, provider.global_position + Vector2(0, 4))


func _repath() -> void:
	_heat_connections.clear()
	for path in _paths.get_paths():
		var _last_provider = null
		for point in path:
			if point in _heat_receivers:
				# DEFECT: attached to every provider, not the nearest one upstream
				for prov in _heat_connections:
					if not _heat_connections[prov].has(point):
						_heat_connections[prov].append(point)

			if point in _heat_providers:
				_last_provider = point
				if not _last_provider in _heat_connections:
					_heat_connections[_last_provider] = []
