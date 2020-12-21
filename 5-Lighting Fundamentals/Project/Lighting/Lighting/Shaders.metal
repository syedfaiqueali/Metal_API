//
/**
 * Copyright (c) 2019 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */


#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct VertexIn {
    float4 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
};

vertex VertexOut vertex_main(const VertexIn vertexIn [[stage_in]],
                          constant Uniforms &uniforms [[buffer(1)]])
{
    VertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * vertexIn.position;
    out.normal = vertexIn.normal;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    float4 sky = float4(0.34, 0.9, 1.0, 1.0);
    float4 earth = float4(0.29, 0.58, 0.2, 1.0);
    float intensity = in.normal.y * 0.5 + 0.5;
    return mix(earth, sky, intensity);
}

