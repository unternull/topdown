extends Node


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_scan_tree(get_tree().current_scene)


func _scan_tree(root: Node) -> void:
	if root == null:
		return
	_try_attach_shadow(root)
	for c in root.get_children():
		_scan_tree(c)


func _on_node_added(n: Node) -> void:
	_try_attach_shadow(n)


func _try_attach_shadow(n: Node) -> void:
	var wants := false
	var v = n.get("has_shadow")
	wants = v == true
	if not wants:
		return
	if n.has_node("Shadow2D"):
		return
	var shadow := Node2D.new()
	shadow.name = "Shadow2D"
	shadow.set_script(load("res://scripts/shadow_2d.gd"))
	n.add_child(shadow)
	shadow.z_as_relative = false
	shadow.z_index = -10
