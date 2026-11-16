shader_type canvas_item;
// La terre des tuiles prend de la profondeur : claire et grumeleuse au bord du vide (là où
// la lumière la touche), de plus en plus sombre et riche en strates, cailloux et racines
// à mesure qu'on s'enfonce. « depth_map » : une case par tuile, distance au vide (0 → 1).

uniform sampler2D depth_map : filter_linear;
uniform vec2 map_tiles = vec2(1.0);
uniform sampler2D detail : repeat_enable, filter_nearest;
uniform float detail_size = 128.0;
uniform float tile = 16.0;
uniform float depth_dark = 0.3;
uniform float detail_contrast = 2.2;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = texture(depth_map, world / (tile * map_tiles)).r;
	vec3 det = 0.5 + (texture(detail, world / detail_size).rgb - 0.5) * detail_contrast;
	float deep = smoothstep(0.06, 0.85, d);
	vec3 col = c.rgb * mix(1.12, depth_dark, deep);
	col = mix(col, col * det * 2.0, 0.85 * smoothstep(0.02, 0.3, d));
	COLOR = vec4(col, c.a);
}
