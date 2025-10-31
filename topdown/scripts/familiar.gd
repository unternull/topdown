extends Node

signal family_counter_changed(family: String, count: int)

@export var families: Array[String] = []

var family_counters: Dictionary = {}


func set_family_count(family: String, count: int) -> void:
	var prev := int(family_counters.get(family, -1))
	if prev == count:
		return
	family_counters[family] = count
	emit_signal("family_counter_changed", family, count)


func has_family(family: String) -> bool:
	return families.has(family)
