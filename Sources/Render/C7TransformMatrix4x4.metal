//
//  C7TransformMatrix4x4.metal
//  Harbeth
//
//  Created by Condy on 2022/11/11.
//

#include "RenderShaders.metal"

// See: https://metalkit.org/2016/02/08/using-metalkit-part-5/

struct Uniforms {
    float4x4 modelMatrix;
};

vertex VertexIO vertex_func(constant VertexIO *vertices [[buffer(0)]],
                            constant Uniforms &uniforms [[buffer(1)]],
                            uint vid [[vertex_id]]) {
    float4x4 matrix = uniforms.modelMatrix;
    VertexIO in = vertices[vid];
    VertexIO out;
    out.position = matrix * float4(in.position);
    out.color = in.color;
    return out;
}

fragment float4 fragment_func(VertexIO vert [[stage_in]]) {
    return vert.color;
}
