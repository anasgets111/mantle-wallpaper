// The picker's preview: the next picture fades in over 300 ms while it settles from a 1.035 zoom
// over 520 ms, both easing out cubically. Run it with a linear 520 ms transition.

float out_cubic(float t) {
    float k = 1.0 - clamp(t, 0.0, 1.0);
    return 1.0 - k * k * k;
}

void main() {
    float fade = out_cubic(u_progress * 520.0 / 300.0);
    float zoom = 1.035 - 0.035 * out_cubic(u_progress);
    vec4 from = mantle_from(v_uv);
    vec4 to = mantle_to((v_uv - 0.5) / zoom + 0.5);
    fragColor = mix(from, to, fade);
}
