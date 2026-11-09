// Balancement au vent des végétaux (herbes, buissons, palmiers, arbres, fleurs).
//
// Le pied de l'image reste fixe ; plus on monte, plus l'image se décale à l'horizontale.
// Le décalage est arrondi au pixel près : le pixel art reste net (pas de flou, pas de
// pixels « coupés en deux »). Le quadrilatère est élargi de « pad » pixels de chaque côté
// pour que ce qui dépasse en se penchant ne soit pas rogné.
//
// Deux réglages globaux, mis à jour par le niveau à chaque image (voir Ambience) :
//   wind_gust    : force signée du vent (négatif = vers la gauche), avec ses rafales ;
//   player_world : position des pieds du héros, pour que l'herbe s'écarte sur son passage.
shader_type canvas_item;

global uniform float wind_gust;
global uniform vec2 player_world;

// Décalage (en pixels) au sommet de l'image quand le vent souffle à pleine force.
uniform float amplitude = 2.0;
// Souplesse : 1 = l'image se penche d'un bloc, 3 = seule la cime bouge (tronc rigide).
uniform float stiffness = 2.0;
// Léger balancement permanent, même sans rafale (en pixels).
uniform float idle_sway = 0.6;
// Vitesse du balancement.
uniform float speed = 1.6;
// Herbe : de combien de pixels elle s'écarte quand le héros la traverse (0 = jamais).
uniform float push = 0.0;
uniform float push_radius = 12.0;
// Tissu suspendu (pagne sur une corde) : c'est le bas qui flotte, le haut reste accroché.
uniform bool hanging = false;
// Marge ajoutée de chaque côté de l'image (en pixels).
uniform float pad = 4.0;

varying vec2 world;      // position du fragment dans le monde
varying float phase;     // décalage de phase propre à chaque plante (selon sa position)
varying vec4 tint;       // couleur et modulate reçus du nœud

void vertex() {
	// Le quadrilatère est élargi ; les UV seront recalées dans fragment(), seul endroit où
	// le rendu « Compatibilité » donne la taille de l'image (TEXTURE_PIXEL_SIZE).
	VERTEX.x += sign(VERTEX.x) * pad;
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	phase = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).x * 0.021;
	tint = COLOR;
}

void fragment() {
	// 0 au point d'attache (le pied, ou le haut d'un tissu suspendu), 1 à l'autre bout.
	float h = hanging ? clamp(UV.y, 0.0, 1.0) : clamp(1.0 - UV.y, 0.0, 1.0);
	float bend = pow(h, stiffness);

	// Rafale qui « passe » d'une plante à l'autre, plus balancement de fond.
	float gust = wind_gust * (0.65 + 0.35 * sin(TIME * 1.3 + phase * 3.0));
	float sway = gust * amplitude + sin(TIME * speed + phase * 7.0) * idle_sway;

	// Le héros écarte l'herbe : elle se couche du côté opposé à lui.
	if (push > 0.0) {
		float dx = world.x - player_world.x;
		float near = smoothstep(push_radius, 2.0, abs(dx)) * step(abs(world.y - player_world.y), 18.0);
		sway += near * push * sign(dx);
	}

	float offset = floor(sway * bend + 0.5);
	// UV.x va de 0 à 1 sur l'image élargie (largeur + 2 × pad) : on revient aux UV de l'image.
	float width = 1.0 / TEXTURE_PIXEL_SIZE.x;
	float u = (UV.x * (width + 2.0 * pad) - pad) / width;
	vec2 uv = vec2(u - offset * TEXTURE_PIXEL_SIZE.x, UV.y);
	vec4 c = texture(TEXTURE, uv);
	if (uv.x < 0.0 || uv.x > 1.0) {
		c.a = 0.0;
	}
	COLOR = c * tint;
}
