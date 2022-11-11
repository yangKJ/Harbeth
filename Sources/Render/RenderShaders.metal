//
//  RenderShaders.metal
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIO {
    float4 position [[position]];
    float4 color;
};
