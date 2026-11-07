#version 440
// stripes, kawt's companion: a stain of corrupted data. Soft blobs make a girl's outline, noise
// eats its edge, she boils inside, her hair runs off in blurred strands every way, and only the
// eyes are sharp. Worked out per cell of a 72 x 108 grid (modules/companion/Her.qml draws this
// into a layer that small and stretches it: the blur is the look, and it costs nothing).
// After a change: tools/qsb.sh makes stripes.frag.qsb again (qsb is in qt6-shadertools).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time; // seconds, wrapped by the hour (services/Companion.qml)
    float fit; // a glitch: 0 .. 1, rows torn sideways
    float blink; // 1: eyes shut
    float sleep; // 0 .. 1: slumped, dim, slow
    float heat; // 0 .. 1: busy, boiling faster
    float lean; // -1 .. 1: walking that way
    float bars; // 1: cut in kawt's bars (the stripes look)
    float steps; // colors in the ramp, c0 .. c<steps - 1>
    vec2 gaze; // -1 .. 1: where her eyes look
    vec4 eye; // the eyes' color
    vec4 c0; // dark to hot, straight alpha
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
    vec4 c5;
    vec4 c6;
    vec4 c7;
    vec4 c8;
};

const float GW = 72.0;
const float GH = 108.0;

// noise like a 256 x 256 table: the same cell always gives the same value
float h2(vec2 p) {
    vec3 q = fract(mod(p.xyx, 256.0) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    float a = h2(i);
    float b = h2(i + vec2(1.0, 0.0));
    float c = h2(i + vec2(0.0, 1.0));
    float d = h2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 0 .. 15/16, the old 4 x 4 ordered dither
float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

float bob() {
    float walk = abs(lean);
    return sin(time * (1.3 + 5.0 * walk)) * 0.006 * (1.0 + walk);
}

// her head: walking it goes first, asleep it hangs
vec2 headAt() {
    return vec2(0.5 + lean * 0.03 + 0.015 * sleep, 0.25 + bob() + 0.035 * sleep);
}

// one soft blob: centre, half sizes, weight, tilt
float blob(vec2 p, vec2 c, vec2 r, float w, float a) {
    vec2 d = p - c;
    float ca = cos(a);
    float sa = sin(a);
    vec2 q = vec2(d.x * ca + d.y * sa, -d.x * sa + d.y * ca) / r;
    float dd = dot(q, q);
    return dd < 9.0 ? w * exp(-dd) : 0.0;
}

// her outline, in 0 .. 1 of the grid
float field(vec2 p) {
    float b = bob();
    float lx = lean * 0.03;
    float droop = 0.035 * sleep;
    float swing = sin(time * 6.0) * 0.18 * abs(lean);
    vec2 hd = headAt();
    float s = blob(p, hd, vec2(0.085, 0.078), 1.0, 0.0);
    s += blob(p, hd - vec2(0.0, 0.04), vec2(0.17, 0.11), 0.8, 0.0); // the hair around it
    // hair falling past the shoulders
    s += blob(p, vec2(0.31 + lx + sin(time * 0.9) * 0.012, 0.33 + b + droop * 0.7), vec2(0.05, 0.15), 0.75, 0.35);
    s += blob(p, vec2(0.69 + lx + sin(time * 1.1) * 0.012, 0.33 + b + droop * 0.7), vec2(0.05, 0.15), 0.75, -0.35);
    s += blob(p, vec2(0.5 + lx * 0.6, 0.41 + b + droop * 0.4), vec2(0.12, 0.045), 0.9, 0.0); // shoulders
    s += blob(p, vec2(0.5 + lx * 0.3, 0.50 + b), vec2(0.075, 0.09), 1.0, 0.0); // waist
    s += blob(p, vec2(0.5, 0.62 + b), vec2(0.09, 0.07), 0.95, 0.0); // hips, a skirt of noise
    s += blob(p, vec2(0.35 + lx * 0.5 + sin(time * 1.2) * 0.01, 0.52 + b + droop * 0.3), vec2(0.026, 0.12), 0.85, 0.12); // arms
    s += blob(p, vec2(0.65 + lx * 0.5 - sin(time * 1.2) * 0.01, 0.52 + b + droop * 0.3), vec2(0.026, 0.12), 0.85, -0.12);
    s += blob(p, vec2(0.455, 0.80), vec2(0.026, 0.12), 0.7, 0.03 + swing); // legs, thinning out
    s += blob(p, vec2(0.545, 0.80), vec2(0.026, 0.12), 0.7, -0.03 - swing);
    return s;
}

vec4 ramp(float i) {
    if (i < 0.5)
        return c0;
    if (i < 1.5)
        return c1;
    if (i < 2.5)
        return c2;
    if (i < 3.5)
        return c3;
    if (i < 4.5)
        return c4;
    if (i < 5.5)
        return c5;
    if (i < 6.5)
        return c6;
    if (i < 7.5)
        return c7;
    return c8;
}

// a slit, from its outer end inwards: two cells on top, three under them; shut, one line of four
bool slit(vec2 r) {
    if (blink > 0.5)
        return r.y == 1.0 && r.x >= 0.0 && r.x <= 3.0;
    return (r.y == 0.0 && r.x >= 0.0 && r.x <= 1.0) || (r.y == 1.0 && r.x >= 1.0 && r.x <= 3.0);
}

void main() {
    vec2 g = floor(qt_TexCoord0 * vec2(GW, GH)); // the cell
    float t = time;
    float tk = floor(t * 12.0);
    float slow = t * 0.15 * mix(1.0, 0.4, sleep);
    float boil = t * 2.2 * mix(1.0, 0.35, sleep) * (1.0 + heat);
    vec2 hd = headAt();
    float y = (g.y + 0.5) / GH;
    bool cut = bars > 0.5;
    vec4 col = vec4(0.0);

    // the stripes look: every third row a gap, each bar of two rows sliding on its own
    if (!cut || mod(g.y, 3.0) < 1.5) {
        float shift = 0.0;
        if (cut)
            shift = floor((vnoise(vec2(floor(g.y / 3.0) * 0.9, t * 0.7)) - 0.5) * 4.0 + 0.5) / GW;
        if (fit > 0.0 && h2(vec2(floor(g.y / 4.0), tk)) > 1.0 - 0.35 * fit)
            shift = (h2(vec2(g.y, tk + 7.0)) - 0.5) * 0.25 * fit;
        float stripe = cut || mod(g.y + floor(t * 4.0), 4.0) > 0.5 ? 1.0 : 0.55;
        float x = (g.x + 0.5) / GW + shift;

        // the edge never holds still
        float nx = vnoise(vec2(x * 7.0, y * 9.0 - t * 0.8)) - 0.5;
        float ny = vnoise(vec2(x * 7.0 + 31.0, y * 9.0 - t * 0.6)) - 0.5;
        float d = smoothstep(0.35, 1.2, field(vec2(x + nx * 0.08, y + ny * 0.06)));

        // hair: strands out of her head every way. Walk back toward the head along a bent
        // line; where the walk meets her, this point is on a strand
        vec2 v = vec2(x - hd.x, (y - hd.y) * 0.8);
        float r = length(v);
        if (r > 0.1 && r < 0.48 && y < 0.62) {
            float ang = atan(v.y, v.x);
            float strand = smoothstep(0.44, 0.74, vnoise(vec2(ang * 8.0 + 40.0, slow + r * 1.5)));
            if (strand > 0.0) {
                float bend = (vnoise(vec2(ang * 3.0, slow * 2.0)) - 0.5) * 0.9;
                float trail = 0.0;
                for (int k = 1; k <= 5; k++) {
                    float fk = float(k);
                    float rr = r - fk * 0.045;
                    if (rr < 0.04)
                        break;
                    float a2 = ang + bend * fk / 5.0;
                    trail = max(trail, smoothstep(0.5, 1.2, field(hd + vec2(cos(a2) * rr, sin(a2) * rr / 0.8))) * (1.0 - fk / 6.0));
                }
                d = max(d, min(1.0, trail * strand * 1.25));
            }
        }

        // inside she boils, kawt's stripes run through her; busy she's hotter, asleep dimmer
        d *= (0.62 + 0.38 * vnoise(vec2(x * 14.0, y * 14.0 - boil))) * stripe;
        d *= (1.0 + 0.2 * heat) * (1.0 - 0.3 * sleep);
        // a few loose bits
        if (d < 0.05 && h2(g + vec2(tk * 3.0, tk)) > 0.998 - 0.01 * fit)
            d = 0.3 + 0.4 * h2(g + vec2(0.0, tk));

        float lv = min(1.0, d) * (steps - 1.0);
        if (!cut)
            lv += (bayer4(g) - 0.5) * 0.9;
        col = ramp(clamp(floor(lv + 0.5), 0.0, steps - 1.0));
    }

    // the eyes: two sharp slits, the one thing that keeps its shape; they look where `gaze` says
    float ey = floor(hd.y * GH + 0.5) + floor(gaze.y * 1.4 + 0.5);
    float ex = floor((hd.x - 0.5) * GW + 0.5) + floor(gaze.x * 2.0 + 0.5);
    float left = floor(GW * 0.43 + 0.5) - 1.0 + ex;
    float right = floor(GW * 0.57 + 0.5) + ex;
    if (slit(vec2(g.x - left, g.y - ey)) || slit(vec2(right - g.x, g.y - ey)))
        col = vec4(eye.rgb, 1.0);

    fragColor = vec4(col.rgb * col.a, col.a) * qt_Opacity;
}
