shader_type canvas_item;

// Hyperspace jump effect for arc transitions.
// Attach to a full-screen ColorRect. Drive `progress` from 0.0 to 1.0 via Tween.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 bg_color : source_color = vec4(0.02, 0.03, 0.06, 1.0);
uniform vec4 streak_color : source_color = vec4(0.45, 0.72, 1.0, 1.0);
uniform vec4 flash_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform float streak_count : hint_range(20.0, 200.0) = 80.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	float angle = atan(uv.y, uv.x);

	// Phase 1 (0.0 - 0.6): Stars stretch into radial streaks
	float stretch_phase = smoothstep(0.0, 0.6, progress);
	// Phase 2 (0.5 - 0.85): Tunnel brightens, streaks intensify
	float tunnel_phase = smoothstep(0.5, 0.85, progress);
	// Phase 3 (0.8 - 1.0): Flash to white then fade to black
	float flash_phase = smoothstep(0.8, 0.92, progress);
	float fadeout = smoothstep(0.92, 1.0, progress);

	// Background darkens then flashes
	vec3 col = bg_color.rgb;

	// Radial streak layer
	float streak_angle = angle * streak_count;
	float streak_id = floor(streak_angle);
	float streak_frac = fract(streak_angle) - 0.5;

	float h = hash(vec2(streak_id, 42.0));
	float streak_brightness = h * 0.8 + 0.2;

	// Streaks get longer and brighter with progress
	float streak_width = mix(0.4, 0.12, stretch_phase);
	float streak_mask = smoothstep(streak_width, 0.0, abs(streak_frac));

	// Radial falloff — streaks appear from center outward
	float radial_start = mix(0.5, 0.02, stretch_phase);
	float radial_mask = smoothstep(radial_start, radial_start + 0.3, dist);

	// Twinkle based on hash
	float twinkle = sin(progress * 20.0 + h * 6.28) * 0.3 + 0.7;

	float streak_intensity = streak_mask * radial_mask * streak_brightness * twinkle;
	streak_intensity *= stretch_phase;

	// Color shifts from cool blue to hot white as tunnel intensifies
	vec3 s_color = mix(streak_color.rgb, flash_color.rgb, tunnel_phase);
	col += s_color * streak_intensity * (0.5 + tunnel_phase * 1.5);

	// Central glow tunnel
	float tunnel_glow = exp(-dist * mix(8.0, 2.0, tunnel_phase)) * tunnel_phase;
	col += flash_color.rgb * tunnel_glow * 0.6;

	// Vignette darkening at edges during early phase
	float vignette = 1.0 - smoothstep(0.3, 0.75, dist) * (1.0 - tunnel_phase);
	col *= vignette;

	// Flash to white
	col = mix(col, flash_color.rgb, flash_phase);

	// Fade to black
	col = mix(col, vec3(0.0), fadeout);

	// Alpha: fully opaque once progress > 0
	float alpha = smoothstep(0.0, 0.05, progress);
	COLOR = vec4(col, alpha);
}
