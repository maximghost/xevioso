// Silhouette colorée (images rémanentes de la Ruée) : la forme du sprite, teintée
// presque entièrement de la couleur du nœud (modulate), en gardant un léger relief.
shader_type canvas_item;

uniform float tint_strength = 0.88;
// Éclat : au-delà de 1, la silhouette paraît lumineuse.
uniform float glow = 1.25;

varying vec4 tint;   // modulate du nœud (reçu à l'étape des sommets)

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, tint.rgb, tint_strength) * glow, tex.a * tint.a);
}
