shader_type canvas_item;

// Animated starfield background for Whisper Crystals.
// Attach to a ColorRect that fills the viewport.

uniform float star_count : hint_range(50.0, 500.0) = 200.0;
uniform float speed : hint_range(0.0, 2.0) = 0.15;
uniform vec4 bg_color : source_color = vec4(0.04, 0.055, 0.10, 1.0);
uniform vec4 star_color : source_color = vec4(0.78, 0.84, 0.90, 1.0);
uniform float nebula_intensity : hint_range(0.0, 1.0) = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv = UV;
	// Deep space background
	COLOR = bg_color;

	// Subtle nebula clouds
	float t = TIME * speed * 0.3;
	float n1 = noise(uv * 3.0 + vec2(t, 0.0));
	float n2 = noise(uv * 6.0 - vec2(0.0, t * 0.7));
	float nebula = (n1 * 0.6 + n2 * 0.4) * nebula_intensity;
	COLOR.rgb += vec3(nebula * 0.08, nebula * 0.04, nebula * 0.15);

	// Star layers
	for (float layer = 1.0; layer <= 3.0; layer += 1.0) {
		float scale = star_count * (0.5 + layer * 0.3);
		vec2 star_uv = uv * scale;
		star_uv.y += TIME * speed * layer * 0.2;
		vec2 grid = floor(star_uv);
		vec2 local = fract(star_uv) - 0.5;

		float h = hash(grid + layer * 100.0);
		vec2 offset = vec2(hash(grid * 1.3 + layer), hash(grid * 2.7 + layer)) - 0.5;
		float dist = length(local - offset * 0.4);

		float brightness = h * (0.3 + layer * 0.2);
		float twinkle = sin(TIME * (2.0 + h * 4.0) + h * 6.28) * 0.3 + 0.7;
		float star_size = 0.02 / (layer * 0.8);

		float star = smoothstep(star_size, 0.0, dist) * brightness * twinkle;
		// Vary star color slightly
		vec3 sc = star_color.rgb * (0.85 + h * 0.3);
		if (h > 0.85) {
			sc = mix(sc, vec3(0.3, 0.7, 1.0), 0.4); // Blue-white stars
		} else if (h > 0.7) {
			sc = mix(sc, vec3(1.0, 0.85, 0.5), 0.3); // Warm yellow stars
		}
		COLOR.rgb += sc * star;
	}
}
