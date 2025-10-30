extends Node2D

@export var color: Color = Color(0, 0, 0, 0.25)
@export var z_index_absolute: int = -10

var _sprite: CanvasItem = null
var _size: Vector2 = Vector2.ZERO


func _ready() -> void:
	z_as_relative = false
	z_index = z_index_absolute
	_sprite = _find_sprite_owner()
	_update_from_sprite()
	_connect_sprite_signals()


func _draw() -> void:
	if _size == Vector2.ZERO:
		return
	var rx: float = max(_size.x * 0.5, 1.0)
	var ry: float = max(_size.y * 0.5, 1.0)
	var pts := _ellipse_points(rx, ry, 32)
	draw_colored_polygon(pts, color)


func _ellipse_points(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(segments)
	var two_pi := TAU
	for i in range(segments):
		var t := two_pi * float(i) / float(segments)
		pts[i] = Vector2(cos(t) * rx, sin(t) * ry)
	return pts


func _find_sprite_owner() -> CanvasItem:
	# Prefer AnimatedSprite2D, then Sprite2D
	for n in get_parent().get_children():
		if n is AnimatedSprite2D:
			return n
	for n in get_parent().get_children():
		if n is Sprite2D:
			return n
	return null


func _update_from_sprite() -> void:
	if _sprite == null:
		return

	# Build a local-space rect from texture size + centered + offset
	var rect_pos := Vector2.ZERO
	var rect_size := Vector2.ZERO
	var local_scale := Vector2.ONE
	var local_pos := Vector2.ZERO

	if _sprite is AnimatedSprite2D:
		var animated_sprite := _sprite as AnimatedSprite2D
		if animated_sprite.sprite_frames == null:
			return
		var anim := String(animated_sprite.animation)
		if anim == "" or not animated_sprite.sprite_frames.has_animation(anim):
			return
		var frame_count := animated_sprite.sprite_frames.get_frame_count(anim)
		if frame_count <= 0:
			return
		var frm: int = clamp(animated_sprite.frame, 0, frame_count - 1)
		var tex := animated_sprite.sprite_frames.get_frame_texture(anim, frm)
		if tex == null:
			return
		rect_size = tex.get_size()
		var centered := animated_sprite.centered
		var offset := animated_sprite.offset
		rect_pos = (-rect_size * 0.5 + offset) if centered else offset
		local_scale = animated_sprite.scale.abs()
		local_pos = animated_sprite.position
	elif _sprite is Sprite2D:
		var s := _sprite as Sprite2D
		if s.texture == null:
			return
		rect_size = s.texture.get_size()
		var centered_s := s.centered
		var offset_s := s.offset
		rect_pos = (-rect_size * 0.5 + offset_s) if centered_s else offset_s
		local_scale = s.scale.abs()
		local_pos = s.position
	else:
		return

	var scaled_size := rect_size * local_scale
	var scaled_pos := rect_pos * local_scale

	if scaled_size == Vector2.ZERO:
		return

	# Width = sprite width; Height = sprite height / 2
	_size = Vector2(scaled_size.x, scaled_size.y * 0.5)

	# Place shadow at the bottom-center of the sprite in parent space
	var bottom_center := local_pos + scaled_pos + Vector2(scaled_size.x * 0.5, scaled_size.y)
	position = bottom_center

	queue_redraw()


func _connect_sprite_signals() -> void:
	if _sprite == null:
		return
	# Update when the drawn rect changes (covers many sprite changes)
	_sprite.item_rect_changed.connect(_on_sprite_changed)
	if _sprite is AnimatedSprite2D:
		var animatedSprite := _sprite as AnimatedSprite2D
		animatedSprite.frame_changed.connect(_on_sprite_changed)
		animatedSprite.sprite_frames_changed.connect(_on_sprite_changed)
	elif _sprite is Sprite2D:
		var s := _sprite as Sprite2D
		s.texture_changed.connect(_on_sprite_changed)


func _on_sprite_changed() -> void:
	_update_from_sprite()
