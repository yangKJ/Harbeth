// 由 Condy 维护。默认中性与稳定比例计算，避免先除颜色再乘回亮度。
#include <metal_stdlib>
using namespace metal;
kernel void C7HighlightShadow(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],constant float &shadows [[buffer(0)]],
    constant float &highlights [[buffer(1)]],constant float &halfOutput [[buffer(2)]],uint2 grid [[thread_position_in_grid]]) {
    if(grid.x>=output.get_width() || grid.y>=output.get_height()) return;
    const float4 color=input.read(grid);
    if(shadows==0.0f && highlights==1.0f) {output.write(color,grid);return;}
    if(color.a<=0.0f) {output.write(float4(0),grid);return;}
    const float lum=clamp(dot(color.rgb/color.a,float3(0.2125f,0.7154f,0.0721f)),0.001f,1.0f);
    const float shadow=clamp(pow(lum,1.0f/(shadows+1.0f))-0.76f*pow(lum,2.0f/(shadows+1.0f))-lum,0.0f,1.0f);
    const float highlight=clamp(1.0f-pow(1.0f-lum,1.0f/(2.0f-highlights))+0.8f*pow(1.0f-lum,2.0f/(2.0f-highlights))-lum,-1.0f,0.0f);
    const float4 result=float4(color.rgb*((lum+shadow+highlight)/lum),color.a);
    output.write(halfOutput>0.5f ? float4(half4(result)):result,grid);
}
