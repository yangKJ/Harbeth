// 由 Condy 维护。目标边界、直色分区和源覆盖率分别处理。
#include <metal_stdlib>
using namespace metal;
kernel void C7Highlights(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],constant float &amount [[buffer(0)]],
    constant float &halfOutput [[buffer(1)]],uint2 grid [[thread_position_in_grid]]) {
    if(grid.x>=output.get_width() || grid.y>=output.get_height()) return;
    const uint2 p=min(grid,uint2(input.get_width()-1,input.get_height()-1));
    const float4 color=input.read(p);
    if(!isfinite(amount) || amount==0.0f) {output.write(color,grid);return;}
    if(color.a<=0.0f) {output.write(float4(0),grid);return;}
    const float l=dot(color.rgb/color.a,float3(0.2126f,0.7152f,0.0722f));
    const float weight=smoothstep(0.5f,1.0f,l);
    const float4 result=float4(color.rgb+amount*weight*color.a,color.a);
    output.write(halfOutput>0.5f ? float4(half4(result)):result,grid);
}
