shader_type canvas_item;

instance uniform vec4 outline_color : source_color = vec4(1.0);
instance uniform float outline_width : hint_range(0.0, 10.0, 1.0) = 3.0;
instance uniform float outline_enabled : hint_range(0.0, 1.0, 1.0) = 0.0;

void fragment() {
	vec4 center = texture(TEXTURE, UV);
	vec2 offset = TEXTURE_PIXEL_SIZE * outline_width;

	bool near_sprite = false;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			if (x == 0 && y == 0) {
				continue;
			}
			near_sprite = near_sprite || texture(TEXTURE, UV + offset * vec2(float(x), float(y))).a > 0.0;
		}
	}

	bool outline = outline_enabled > 0.5 && near_sprite && center.a == 0.0;

	COLOR = center;
	if (outline) {
		COLOR = outline_color;
	}
}