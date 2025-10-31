extends Node

@export var families: Array[String] = []

signal family_counter_changed(family: String, count: int)

var familyCounters: Dictionary = {}


func set_family_count(family: String, count: int) -> void:
	var prev := int(familyCounters.get(family, -1))
	if prev == count:
		return
	familyCounters[family] = count
	emit_signal("family_counter_changed", family, count)


func has_family(family: String) -> bool:
	return families.has(family)


