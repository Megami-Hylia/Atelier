#include <metal_stdlib>
using namespace metal;

struct Stamp {
    float4 geometry;
    float4 color;
    float4 shape;
    float4 grain;
    float4 texture;
    float4 pickup;
    float4 rendering;
    float4 variation;
};
struct TileInfo { uint2 origin; uint2 size; uint count; };
constant sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);
constant sampler repeatSampler(coord::normalized, address::repeat, filter::linear);

float3 blendRGB(float3 base, float3 paint, int mode) {
    if (mode == 1) return base * paint;
    if (mode == 2) return 1 - (1 - base) * (1 - paint);
    return paint;
}

kernel void clearTexture(texture2d<float, access::write> out [[texture(0)]],
                         constant float4 &color [[buffer(0)]], uint2 p [[thread_position_in_grid]]) {
    if (p.x < out.get_width() && p.y < out.get_height()) out.write(color, p);
}

kernel void paintTile(texture2d<float, access::read> source [[texture(0)]],
                      texture2d<float, access::write> target [[texture(1)]],
                      texture2d<float, access::sample> shapeSource [[texture(2)]],
                      texture2d<float, access::sample> grainSource [[texture(3)]],
                      texture2d<float, access::read> pickupSource [[texture(4)]],
                      texture2d<float, access::sample> secondaryShape [[texture(5)]],
                      texture2d<float, access::sample> secondaryGrain [[texture(6)]],
                      constant Stamp *stamps [[buffer(0)]], constant TileInfo &tile [[buffer(1)]],
                      uint2 local [[thread_position_in_grid]]) {
    if (any(local >= tile.size)) return;
    uint2 pixel = local + tile.origin;
    if (pixel.x >= target.get_width() || pixel.y >= target.get_height()) return;
    float2 position = float2(pixel) + 0.5;
    float4 color = source.read(pixel); // Premultiplied linear RGBA throughout compositing.
    for (uint i = 0; i < tile.count; i++) {
        Stamp s = stamps[i];
        float2 delta = (position - s.geometry.xy) / max(0.05f, s.geometry.z);
        if (any(abs(delta) > 1.5)) continue;
        float cs = cos(s.geometry.w), sn = sin(s.geometry.w);
        float2 uv = float2(delta.x * cs + delta.y * sn, -delta.x * sn + delta.y * cs) / s.shape.xy;
        if (any(abs(uv) > 1)) continue;
        float mask = s.variation.y > 0.5 ? secondaryShape.sample(linearSampler, uv * 0.5 + 0.5).r : shapeSource.sample(linearSampler, uv * 0.5 + 0.5).r;
        float2 grainPosition = mix(uv * s.geometry.z, position, s.texture.x);
        float2 g = mix(grainPosition / max(0.1f, s.geometry.z), grainPosition / 32, s.texture.y);
        float cg = cos(s.texture.z), sg = sin(s.texture.z);
        g = float2(g.x * cg - g.y * sg, g.x * sg + g.y * cg) / s.grain.x;
        float grainValue = s.variation.y > 0.5 ? secondaryGrain.sample(repeatSampler, g).r : grainSource.sample(repeatSampler, g).r;
        float grain = clamp((grainValue - 0.5) * s.grain.z + 0.5 + s.grain.w, 0.0f, 1.0f);
        mask *= mix(1.0f, grain, s.grain.y);
        mask *= clamp(1 - s.texture.w * (uv.y + 1) * 0.5, 0.0f, 1.0f);
        float alpha = clamp(mask * s.color.w, 0.0f, 1.0f);
        if (alpha < s.rendering.z) continue;
        int tool = int(s.rendering.y);
        if (tool == 2) { color *= 1 - alpha; continue; }
        int2 pickupPixel = clamp(int2(position - s.pickup.xy), int2(0), int2(source.get_width() - 1, source.get_height() - 1));
        float4 pickup = pickupSource.read(uint2(pickupPixel));
        if (tool == 1) {
            // shortcut: pickup uses pre-stroke pixels; evaluate per-stamp ping-pong for self-advection parity.
            color = mix(color, pickup, alpha * s.pickup.w);
            continue;
        }
        float3 rgb = s.color.rgb;
        if (pickup.a > 0.00001) {
            float3 pigment = pickup.rgb / pickup.a;
            float luminance = dot(pigment, float3(0.2126, 0.7152, 0.0722));
            rgb = mix(rgb, pigment, clamp((s.pickup.z + s.pickup.w) * pickup.a * mix(1.0f, luminance, s.rendering.w), 0.0f, 1.0f));
        }
        float3 baseRGB = color.a > 0.00001 ? color.rgb / color.a : rgb;
        float3 blended = blendRGB(baseRGB, rgb, int(s.rendering.x));
        // W3C source-over blend formula also covers a transparent destination.
        color.rgb = (1 - alpha) * color.rgb + alpha * ((1 - color.a) * rgb + color.a * blended);
        color.a = alpha + color.a * (1 - alpha);
    }
    target.write(clamp(color, 0.0f, 1.0f), pixel);
}

kernel void compositeLayer(texture2d<float, access::read> base [[texture(0)]],
                           texture2d<float, access::read> layer [[texture(1)]],
                           texture2d<float, access::write> output [[texture(2)]],
                           constant float2 &options [[buffer(0)]], uint2 p [[thread_position_in_grid]]) {
    if (p.x >= output.get_width() || p.y >= output.get_height()) return;
    float4 a = base.read(p), b = layer.read(p) * options.x;
    float3 ca = a.a > 0.00001 ? a.rgb / a.a : float3(0);
    float3 cb = b.a > 0.00001 ? b.rgb / b.a : float3(0);
    float3 blended = blendRGB(ca, cb, int(options.y));
    output.write(float4((1-b.a)*a.rgb + (1-a.a)*b.rgb + a.a*b.a*blended, b.a + a.a*(1-b.a)), p);
}

struct ScreenVertex { float4 position [[position]]; float2 uv; };
vertex ScreenVertex canvasVertex(uint id [[vertex_id]]) {
    float2 positions[] = {float2(-1,1),float2(-1,-1),float2(1,1),float2(1,-1)};
    float2 uvs[] = {float2(0,0),float2(0,1),float2(1,0),float2(1,1)};
    return {float4(positions[id],0,1),uvs[id]};
}
fragment float4 canvasFragment(ScreenVertex in [[stage_in]], texture2d<float> image [[texture(0)]]) {
    float4 c = image.sample(linearSampler, in.uv);
    return float4(c.rgb + (1-c.a),1);
}
