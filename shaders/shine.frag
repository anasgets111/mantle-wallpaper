// A slanted band of light sweeping left to right across a chosen card's picture as `progress` goes
// from -0.35 to 1.35: a bright core in a wider glow. Drawn with `blend = "plus_lighter"`.

void main() {
    vec2 p = v_uv * u_size;
    float t = (p.x + 0.45 * p.y) / (u_size.x + 0.45 * u_size.y) - u_progress;
    float core = t * 11.0;
    float halo = t * 3.5;
    float band = 0.34 * exp(-core * core) + 0.08 * exp(-halo * halo);
    fragColor = vec4(vec3(band), band);
}
