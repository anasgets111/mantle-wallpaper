// The indeterminate loading ring: an arc that grows and shrinks as it chases round a faint track.
// `u_progress` runs 0..18 linearly over 18 cycles of 1440 ms; each cycle the arc grows from 30° to
// 250° with its tail fixed, then shrinks back with its head fixed, the whole ring turning a full
// turn every 800 ms and 220° more each cycle, so 18 cycles end where they began.

uniform vec3 color;
uniform float line; // stroke width, px

const float PI = 3.14159265;

float in_out_cubic(float t) {
    return t < 0.5 ? 4.0 * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0;
}

void main() {
    float cycle = floor(u_progress);
    float f = u_progress - cycle;
    float start = -90.0;
    float sweep;
    if (f < 0.5) {
        sweep = 30.0 + 220.0 * in_out_cubic(f * 2.0);
    } else {
        float g = in_out_cubic(f * 2.0 - 1.0);
        start += 220.0 * g;
        sweep = 250.0 - 220.0 * g;
    }
    float turn = u_progress * 1440.0 / 800.0 * 360.0 + cycle * 220.0;
    start += turn;

    vec2 p = (v_uv - 0.5) * u_size;
    float radius = (min(u_size.x, u_size.y) - line) / 2.0;
    float ring = abs(length(p) - radius) - line / 2.0;
    float on_ring = clamp(0.5 - ring, 0.0, 1.0);

    // Angle clockwise from three o'clock in degrees, as Qt's PathAngleArc counts.
    float a = mod(degrees(atan(p.y, p.x)) - start, 360.0);
    // Round caps: distance to the arc's two ends.
    float s0 = radians(start), s1 = radians(start + sweep);
    vec2 e0 = radius * vec2(cos(s0), sin(s0));
    vec2 e1 = radius * vec2(cos(s1), sin(s1));
    float cap = min(length(p - e0), length(p - e1)) - line / 2.0;
    float on_arc = max(a <= sweep ? on_ring : 0.0, clamp(0.5 - cap, 0.0, 1.0));

    float alpha = max(on_arc, on_ring * 0.16);
    fragColor = vec4(color * alpha, alpha);
}
