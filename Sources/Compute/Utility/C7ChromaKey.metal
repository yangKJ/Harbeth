// 由 Condy 维护。直色判色、关联RGBA应用matte，替换色已预乘。
#include <metal_stdlib>
using namespace metal;
kernel void C7ChromaKey(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],constant float &threshold [[buffer(0)]],
    constant float &smoothing [[buffer(1)]],constant float3 &key [[buffer(2)]],
    constant float4 &replacement [[buffer(3)]],constant float &halfOutput [[buffer(4)]],uint2 grid [[thread_position_in_grid]]) {
    if(grid.x>=output.get_width() || grid.y>=output.get_height()) return;
    const float4 source=input.read(grid);
    const float3 rgb=source.a>0.0f ? source.rgb/source.a:float3(0);
    const float keyY=dot(key,float3(0.2989f,0.5866f,0.1145f));
    const float y=dot(rgb,float3(0.2989f,0.5866f,0.1145f));
    const float2 keyChroma=float2(0.7132f*(key.r-keyY),0.5647f*(key.b-keyY));
    const float2 chroma=float2(0.7132f*(rgb.r-y),0.5647f*(rgb.b-y));
    const float d=distance(chroma,keyChroma);
    const float coverage=smoothing<=0.0f ? (d>threshold ? 1.0f:0.0f):smoothstep(threshold,threshold+smoothing,d);
    float4 result=source.a>0.0f ? source*coverage:float4(0);
    if(result.a==0.0f && replacement.a!=0.0f) result=replacement;
    output.write(halfOutput>0.5f ? float4(half4(result)):result,grid);
}
