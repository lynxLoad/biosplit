shader_type canvas_item;

uniform int octaves: hint_range(0, 16) = 8;
uniform sampler2D color_gradient: hint_default_white;

uniform float speed_1: hint_range(0.0, 4.0) = 0.4;
uniform float speed_2: hint_range(0.0, 4.0) = 0.15;

uniform float smoke_persistance: hint_range(0.0, 8.0) = 2.5;
uniform float smoke_amplitude: hint_range(0.0, 4.0) = 0.55;
uniform float smoke_starting_offset: hint_range(0.0, 2.0) = 0.02;

uniform float noise_scale: hint_range(0.1, 20.0) = 4.0;

// --- Анимация формы ---
uniform float evolve_speed: hint_range(0.0, 2.0) = 0.3;
uniform float evolve_strength: hint_range(0.0, 2.0) = 0.4;

// --- Прозрачность ---
uniform float opacity: hint_range(0.0, 1.0) = 1.0;
uniform float alpha_min: hint_range(0.0, 1.0) = 0.25;
uniform float alpha_max: hint_range(0.0, 1.0) = 0.65;

// --- Маска направления ---
uniform int  fade_direction: hint_range(0, 3) = 0;
uniform float fade_start: hint_range(0.0, 1.0) = 0.0;
uniform float fade_end:   hint_range(0.0, 1.0) = 0.7;
uniform bool  fade_invert = false;
uniform float fade_power: hint_range(0.2, 5.0) = 1.0;

float rand2(vec2 co) {
	return fract(cos(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise_simple(vec2 vl) {
	float min_step = 1.0;
	vec2 grid = floor(vl);
	vec2 grid_pnt_2 = vec2(grid.x, grid.y + min_step);
	vec2 grid_pnt_3 = vec2(grid.x + min_step, grid.y);
	vec2 grid_pnt_4 = vec2(grid_pnt_3.x, grid_pnt_2.y);
	float s = rand2(grid);
	float t = rand2(grid_pnt_3);
	float u = rand2(grid_pnt_2);
	float v = rand2(grid_pnt_4);
	float x1 = smoothstep(0.0, 1.0, fract(vl.x));
	float interp_x1 = mix(s, t, x1);
	float interp_x2 = mix(u, v, x1);
	float y = smoothstep(0.0, 1.0, fract(vl.y));
	return mix(interp_x1, interp_x2, y);
}

float fractal_noise(vec2 vl) {
	float persistance = smoke_persistance;
	float amplitude = smoke_amplitude;
	float result = smoke_starting_offset;
	vec2 p = vl;
	for (int i = 0; i < octaves; i++) {
		result += amplitude * value_noise_simple(p);
		amplitude /= persistance;
		p *= persistance;
	}
	return result;
}

float complex_fbm(vec2 p) {
	float slow = TIME * speed_1;
	float fast = TIME * speed_2;
	float evolve = TIME * evolve_speed;

	// Анимированный варп — «живая» форма
	vec2 warp = vec2(
		sin(p.y * 1.7 + evolve * 1.1) + cos(p.x * 0.9 - evolve * 0.7),
		cos(p.x * 1.3 - evolve * 0.9) + sin(p.y * 1.1 + evolve * 0.5)
	) * evolve_strength;

	vec2 q = p + warp;

	vec2 offset_1 = vec2(slow, 0.0);
	vec2 offset_2 = vec2(sin(fast) * 0.1, 0.0);

	return fractal_noise(
		q + offset_1 + fractal_noise(
			q + fractal_noise(
				q + 2.0 * fractal_noise(q - offset_2)
			)
		)
	);
}

float direction_mask(vec2 uv) {
	float t;
	if (fade_direction == 0)      t = uv.y;
	else if (fade_direction == 1) t = 1.0 - uv.y;
	else if (fade_direction == 2) t = uv.x;
	else                          t = 1.0 - uv.x;

	if (fade_invert) t = 1.0 - t;

	float m = smoothstep(fade_start, fade_end, t);
	return pow(m, fade_power);
}

void fragment() {
	vec2 uv = UV;
	float fbm = complex_fbm(uv * noise_scale);

	vec3 col = texture(color_gradient, vec2(fbm)).rgb;

	float a = smoothstep(alpha_min, alpha_max, fbm) * opacity;
	a *= direction_mask(uv);

	COLOR = vec4(col, a);
}