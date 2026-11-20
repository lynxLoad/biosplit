extends RefCounted

const ALPHA_THRESHOLD := 0.1

static func build(texture: Texture2D) -> BitMap:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		var error := image.decompress()
		if error != OK:
			push_error("Не удалось распаковать текстуру для альфа-маски: %s" % texture.resource_path)
			return null
	var mask := BitMap.new()
	mask.create_from_image_alpha(image, ALPHA_THRESHOLD)
	return mask

static func contains(mask: BitMap, point: Vector2, control_size: Vector2) -> bool:
	if mask == null or control_size.x <= 0.0 or control_size.y <= 0.0:
		return false
	if not Rect2(Vector2.ZERO, control_size).has_point(point):
		return false
	var mask_size := mask.get_size()
	var pixel := Vector2i(
		floori(point.x * mask_size.x / control_size.x),
		floori(point.y * mask_size.y / control_size.y)
	)
	return mask.get_bitv(pixel)
