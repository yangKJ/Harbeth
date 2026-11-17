//
//  C7OrderedDither.metal
//  Harbeth
//
//  Created by Condy on 2026/10/14.
//

#include <metal_stdlib>
using namespace metal;

static inline float orderedCellNoise(int2 cell, uint pattern, float seed) {
    if (pattern == 0u) { return 0.0f; }
    if (pattern == 2u) {
        const float2 position = float2(cell) + float2(seed, seed * 0.754877666f);
        return fract(52.9829189f * fract(dot(position, float2(0.06711056f, 0.00583715f)))) - 0.5f;
    }
    const uint bitCount = pattern == 3u ? 1u : (pattern == 4u ? 3u : 2u);
    constexpr uint digits[4] = {0u, 2u, 3u, 1u};
    uint rank = 0u;
    for (uint bit = 0u; bit < bitCount; ++bit) {
        const uint2 position = (uint2(cell) >> bit) & 1u;
        rank = rank * 4u + digits[position.y * 2u + position.x];
    }
    return (float(rank) + 0.5f) / float(1u << (bitCount * 2u)) - 0.5f;
}

// 平均在输出逻辑单元定义，采样与写回分别映射到输入和输出局部坐标。
static inline int2 orderedInputPoint(float2 global,constant float4 *context) {
    const float4 input=context[0],output=context[1];
    const float2 local=all(input.zw==output.zw) ? global-input.xy : global/max(output.zw,float2(1))*input.zw-input.xy;
    return int2(local);
}
static inline __attribute__((always_inline)) void orderedDitherCell(
    texture2d<float,access::write> output,texture2d<float,access::read> input,
    constant float *levelsPointer,constant float *pixelSizePointer,constant float *patternPointer,
    constant float *strengthPointer,constant float *seedPointer,constant float4 *context,
    constant float &halfOutput,int2 cell) {
    const int size=int(clamp(round(*pixelSizePointer),1.0f,32.0f));
    const int2 origin=int2(floor(context[1].xy)),logical=int2(max(context[1].zw,float2(1)));
    const int2 outputSize=int2(output.get_width(),output.get_height());
    const int2 inputSize=int2(input.get_width(),input.get_height());
    const int2 globalStart=cell*size;
    const int2 localStart=max(globalStart-origin,int2(0));
    const int2 localEnd=min(globalStart+size-origin,outputSize);
    const int2 sampleStart=max(globalStart,int2(0)),sampleEnd=min(globalStart+size,logical);
    float3 sum=float3(0);float alpha=0.0f;
    for(int y=sampleStart.y;y<sampleEnd.y;y++) {
        for(int x=sampleStart.x;x<sampleEnd.x;x++) {
            const int2 p=orderedInputPoint(float2(x,y),context);
            if(any(p<0) || any(p>=inputSize)) continue;
            const float4 value=input.read(uint2(p));
            if(value.a>0.0f) {sum+=value.rgb;alpha+=value.a;}
        }
    }
    // 保留目录的Half调色板边界，但正覆盖不使用固定侵蚀阈值。
    const float3 color=float3(half3(alpha>0.0f ? sum/alpha:float3(0)));
    const float levels=clamp(round(*levelsPointer),2.0f,256.0f)-1.0f;
    const float noise=orderedCellNoise(cell,uint(round(*patternPointer)),*seedPointer);
    const float strength=clamp(*strengthPointer,0.0f,1.0f);
    const float3 palette=float3(half3(clamp(floor(clamp(color,0.0f,1.0f)*levels+0.5f+noise*strength)/levels,0.0f,1.0f)));
    for(int y=localStart.y;y<localEnd.y;y++) {
        for(int x=localStart.x;x<localEnd.x;x++) {
            const int2 source=orderedInputPoint(float2(x,y)+float2(origin),context);
            const float coverage=all(source>=0) && all(source<inputSize) ? input.read(uint2(source)).a:0.0f;
            const float4 result=float4(palette*coverage,coverage);
            output.write(halfOutput>0.5f ? float4(half4(result)):result,uint2(x,y));
        }
    }
}

kernel void C7OrderedDither(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],constant float *levels [[buffer(0)]],
    constant float *pixelSize [[buffer(1)]],constant float *pattern [[buffer(2)]],constant float *strength [[buffer(3)]],
    constant float *seed [[buffer(4)]],constant float &halfOutput [[buffer(5)]],constant float4 *context [[buffer(30)]],
    uint2 grid [[thread_position_in_grid]]) {
    const int size=int(clamp(round(*pixelSize),1.0f,32.0f));
    const int2 origin=int2(floor(context[1].xy));
    if(grid.x>=output.get_width() || grid.y>=output.get_height()) return;
    const int2 cell=int2(floor(float2(int2(grid)+origin)/float(size)));
    if(any(int2(grid)!=max(cell*size-origin,int2(0)))) return;
    orderedDitherCell(output,input,levels,pixelSize,pattern,strength,seed,context,halfOutput,cell);
}

kernel void C7OrderedDitherCells(texture2d<float,access::write> output [[texture(0)]],
    texture2d<float,access::read> input [[texture(1)]],constant float *levels [[buffer(0)]],
    constant float *pixelSize [[buffer(1)]],constant float *pattern [[buffer(2)]],constant float *strength [[buffer(3)]],
    constant float *seed [[buffer(4)]],constant float &halfOutput [[buffer(5)]],constant float4 *context [[buffer(30)]],
    uint2 grid [[thread_position_in_grid]]) {
    const int size=int(clamp(round(*pixelSize),1.0f,32.0f));
    const int2 origin=int2(floor(context[1].xy));
    const int2 first=int2(floor(float2(origin)/float(size)));
    const int2 last=int2(floor(float2(origin+int2(output.get_width(),output.get_height())-1)/float(size)));
    if(any(grid>=uint2(last-first+1))) return;
    const int2 cell=first+int2(grid);
    orderedDitherCell(output,input,levels,pixelSize,pattern,strength,seed,context,halfOutput,cell);
}
