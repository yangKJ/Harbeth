//
//  C7Morphology.metal
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

#include <metal_stdlib>
using namespace metal;

kernel void C7Morphology(texture2d<half, access::read> inputTexture [[texture(0)]],
                         texture2d<half, access::write> outputTexture [[texture(1)]],
                         constant float &operation [[buffer(0)]],
                         constant float &kernelSize [[buffer(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
    const uint width = inputTexture.get_width();
    const uint height = inputTexture.get_height();
    
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    
    const int kSize = int(kernelSize);
    const int halfSize = kSize / 2;
    half4 result = inputTexture.read(gid);
    
    if (operation == 0) {
        for (int x = -halfSize; x <= halfSize; x++) {
            for (int y = -halfSize; y <= halfSize; y++) {
                int2 offset = int2(x, y);
                int2 pos = int2(gid) + offset;
                
                if (pos.x >= 0 && pos.x < int(width) && pos.y >= 0 && pos.y < int(height)) {
                    half4 pixel = inputTexture.read(uint2(pos));
                    result = min(result, pixel);
                }
            }
        }
    } else if (operation == 1) {
        for (int x = -halfSize; x <= halfSize; x++) {
            for (int y = -halfSize; y <= halfSize; y++) {
                int2 offset = int2(x, y);
                int2 pos = int2(gid) + offset;
                if (pos.x >= 0 && pos.x < int(width) && pos.y >= 0 && pos.y < int(height)) {
                    half4 pixel = inputTexture.read(uint2(pos));
                    result = max(result, pixel);
                }
            }
        }
    }
    
    outputTexture.write(result, gid);
}
