extends Node
## Validates patrolling-related level rules at scene startup.

@onready var grid: Node = get_node("/root/Grid")


func _ready() -> void:
	_validate_patrolling_nodes()


func _validate_patrolling_nodes() -> void:
	var patrollers := get_tree().get_nodes_in_group("_patrolling_scan")
	if patrollers.is_empty():
		# Fallback: walk tree and find nodes with Patrolling script by name
		patrollers = []
		var root: Node = get_tree().current_scene
		if root == null:
			root = get_tree().root
		if root != null:
			_patrollers_in_subtree(root, patrollers)
	for p in patrollers:
		if p == null:
			continue
		if not (p as Node).has_method("_validate_route_rules"):
			continue
		# Call the patroller's validation; it will assert on failures
		(p as Object).call("_validate_route_rules")
		# Ensure owner has GridActor
		var owner := (p as Node).get_parent()
		assert(
			owner != null and owner.get_node_or_null("GridActor") != null,
			"Patrolling owner missing GridActor"
		)


func _patrollers_in_subtree(root: Node, out: Array) -> void:
	if root == null:
		return
	for c in root.get_children():
		if c.get("points") != null and c.has_method("_validate_route_rules"):
			out.append(c)
		_patrollers_in_subtree(c, out)
