shader_type canvas_item;
// Balancement du feuillage (fougères, palmes, colocases) : le haut de l'image oscille, le pied
// reste planté. Chaque plante a sa propre phase (d'après sa position dans le monde).
uniform float amount = 1.5;
uniform float speed = 1.4;

void vertex() {
	float k = 1.0 - UV.y;
	float phase = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).x * 0.045;
	VERTEX.x += (sin(TIME * speed + phase) + 0.35 * sin(TIME * speed * 2.3 + phase * 1.7)) * amount * k * k;
}
