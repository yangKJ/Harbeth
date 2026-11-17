// 由 Condy 维护。30种目录模式共享关联外壳，不透明颜色公式保持各自意图。
#include <metal_stdlib>
using namespace metal;

static float3 catalogSetLum(float3 c,float tt);
static float3 catalogSetSat(float3 c,float s);
static float3 catalogSetLum(float3 c, float tt) {
    float d = tt - dot(c, float3(0.3, 0.59, 0.11));
    c = c + float3(d);
    float l = dot(c, float3(0.3, 0.59, 0.11));
    float n = min(min(c.r, c.g), c.b);
    float x = max(max(c.r, c.g), c.b);
    if (n < 0.0f) {
        c.r = l + ((c.r - l) * l) / max(l - n, 0.000001f);
        c.g = l + ((c.g - l) * l) / max(l - n, 0.000001f);
        c.b = l + ((c.b - l) * l) / max(l - n, 0.000001f);
    }
    if (x > 1.0f) {
        c.r = l + ((c.r - l) * (1.0f - l)) / max(x - l, 0.000001f);
        c.g = l + ((c.g - l) * (1.0f - l)) / max(x - l, 0.000001f);
        c.b = l + ((c.b - l) * (1.0f - l)) / max(x - l, 0.000001f);
    }
    return c;
}

static float3 catalogSetSat(float3 c, float s) {
    if (c.r > c.g) {
        if (c.r > c.b) {
            if (c.g > c.b) {

                c.g = ((c.g - c.b) * s) / (c.r - c.b);
                c.b = 0.0f;
            } else {

                c.b = ((c.b - c.g) * s) / (c.r - c.g);
                c.g = 0.0f;
            }
            c.r = s;
        } else {

            c.r = ((c.r - c.g) * s) / (c.b - c.g);
            c.b = s;
            c.r = 0.0f;
        }
    } else if (c.r > c.b) {

        c.r = ((c.r - c.b) * s) / (c.g - c.b);
        c.g = s;
        c.b = 0.0f;
    } else if (c.g > c.b) {

        c.b = ((c.b - c.r) * s) / (c.g - c.r);
        c.g = s;
        c.r = 0.0f;
    } else if (c.b > c.g) {

        c.g = ((c.g - c.r) * s) / (c.b - c.r);
        c.b = s;
        c.r = 0.0f;
    } else {
        c = float3(0.0f);
    }
    return c;
}

template<int Mode>
static inline float3 catalogColor(float3 b,float3 s) {
    if (Mode == 0) { return min(b + s, float3(1)); }
    if (Mode == 1) { return s; }
    if (Mode == 2) { float3 c; for(uint i=0;i<3;i++) c[i] = s[i] == 0.0f ? (b[i] == 1.0f ? 1.0f : 0.0f) : 1.0f-(1.0f-b[i])/s[i]; return c; }
    if (Mode == 3) { const float3 denominator = 1.0f-clamp(s,0.0f,0.99f); return select(float3(1), b/denominator, b+s <= 1.0f); }
    if (Mode == 4) { return min(b,s); }
    if (Mode == 5) { return dot(s,float3(0.299f,0.587f,0.114f)) < dot(b,float3(0.299f,0.587f,0.114f)) ? s:b; }
    if (Mode == 6) { return abs(b-s); }
    if (Mode == 7) { return s; }
    if (Mode == 8) { float3 c; for(uint i=0;i<3;i++) c[i] = s[i] == 0.0f || b[i]/s[i] > 1.0f ? 1.0f : b[i]/s[i]; return c; }
    if (Mode == 9) { return b+s-2.0f*b*s; }
    if (Mode == 10) { return select(1.0f-2.0f*(1.0f-b)*(1.0f-s),2.0f*b*s,s<0.5f); }
    if (Mode == 11) { return select(float3(0),float3(1),b+s>1.0f); }
    if (Mode == 12) { return catalogSetLum(catalogSetSat(s,max(b.r,max(b.g,b.b))-min(b.r,min(b.g,b.b))),dot(s,float3(0.3f,0.59f,0.11f))); }
    if (Mode == 13) { return max(b,s); }
    if (Mode == 14) { return dot(s,float3(0.299f,0.587f,0.114f)) > dot(b,float3(0.299f,0.587f,0.114f)) ? s:b; }
    if (Mode == 15) { return b+s-1.0f; }
    if (Mode == 16) { return b+2.0f*s-1.0f; }
    if (Mode == 17) { return catalogSetLum(b,dot(s,float3(0.3f,0.59f,0.11f))); }
    if (Mode == 18) { return s; }
    if (Mode == 19) { return b*s; }
    if (Mode == 20) { return s; }
    if (Mode == 21) { return select(1.0f-2.0f*(1.0f-b)*(1.0f-s),2.0f*b*s,b<0.5f); }
    if (Mode == 22) { return select(max(b,2.0f*(s-0.5f)),min(b,2.0f*s),s<0.5f); }
    if (Mode == 23) { return float3(dot(b,float3(0.299f,0.587f,0.114f)))+s-dot(s,float3(0.299f,0.587f,0.114f)); }
    if (Mode == 24) { return 1.0f-(1.0f-s)*(1.0f-b); }
    if (Mode == 25) { return b*(b+2.0f*s*(1.0f-b)); }
    if (Mode == 26) { return s; }
    if (Mode == 27) { return b-s; }
    if (Mode == 28) { float3 c;for(uint i=0;i<3;i++) c[i]=s[i]<0.5f ? 1.0f-(1.0f-b[i])/(2.0f*s[i]+0.001f) : b[i]/(2.0f*(1.0f-s[i])+0.001f);return c; }
    if (Mode == 29) { const float l=dot(b,float3(0.299f,0.587f,0.114f)); const float g=dot(s,float3(0.299f,0.587f,0.114f)); return clamp(float3(l)+s-g,0.0f,1.0f); }
    return s;
}

template<int Mode>
static inline __attribute__((always_inline)) void catalogPixel(
    texture2d<float,access::write> output,texture2d<float,access::read> input,
    texture2d<float,access::sample> foreground,constant float &intensity,constant float &halfOutput,uint2 grid) {
    if(grid.x>=output.get_width() || grid.y>=output.get_height()) return;
    const float4 base=input.read(grid);
    if(!isfinite(intensity) || intensity<=0.0f) { output.write(base,grid);return; }
    const float amount=clamp(intensity,0.0f,1.0f);
    constexpr sampler samplerState(coord::normalized,address::clamp_to_edge,filter::linear);
    const float2 uv=(float2(grid)+0.5f)/float2(output.get_width(),output.get_height());
    const float4 sampled=foreground.sample(samplerState,uv);
    const float4 top=sampled.a>0.0f ? sampled:float4(0);
    float4 result;
    if(Mode==18) {
        // 预乘亮度已含一次覆盖，不能再乘mask Alpha；白mask保持来源、黑mask清除RGBA。
        const float coverage=top.a>0.0f ? clamp(dot(top.rgb,float3(1.0f/3.0f)),0.0f,1.0f):0.0f;
        result=base*(1.0f+amount*(coverage-1.0f));
    } else if(Mode==7) {
        result=amount==1.0f ? top:base+(top-base)*amount;
    } else if(Mode==1) {
        result=base.a>0.0f ? float4(base.rgb*(1.0f-top.a*amount)+top.rgb*(base.a*amount),base.a):float4(0);
    } else {
        if(top.a<=0.0f) { output.write(base,grid);return; }
        float4 composed;
        if(Mode==20 || Mode==26) composed=float4(top.rgb+base.rgb*(1.0f-top.a),top.a+base.a*(1.0f-top.a));
        else if(base.a<=0.0f) composed=top;
        else {
            const float3 mixed=catalogColor<Mode>(base.rgb/base.a,top.rgb/top.a);
            composed=float4(base.rgb*(1.0f-top.a)+top.rgb*(1.0f-base.a)+mixed*(base.a*top.a),top.a+base.a*(1.0f-top.a));
        }
        result=amount==1.0f ? composed:base+(composed-base)*amount;
    }
    if(result.a<=0.0f) result=float4(0);
    output.write(halfOutput>0.5f ? float4(half4(result)):result,grid);
}

kernel void C7BlendColorAdd(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<0>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendColorAlpha(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<1>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendColorBurn(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<2>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendColorDodge(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<3>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendDarken(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<4>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendDarkerColor(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<5>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendDifference(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<6>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendDissolve(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<7>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendDivide(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<8>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendExclusion(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<9>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendHardLight(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<10>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendHardMix(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<11>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendHue(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<12>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendLighten(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<13>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendLighterColor(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<14>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendLinearBurn(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<15>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendLinearLight(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<16>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendLuminosity(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<17>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendMask(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<18>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendMultiply(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<19>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendNormal(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<20>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendOverlay(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<21>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendPinLight(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<22>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendSaturation(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<23>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendScreen(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<24>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendSoftLight(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<25>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendSourceOver(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<26>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendSubtract(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<27>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendVividLight(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<28>(output,input,foreground,intensity,halfOutput,grid);
}

kernel void C7BlendColor(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],texture2d<float,access::sample> foreground [[texture(2)]],
    constant float &intensity [[buffer(0)]],constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    catalogPixel<29>(output,input,foreground,intensity,halfOutput,grid);
}
