/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders used for this sample
*/

#include <metal_stdlib>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands.
#include "AAPLShaderTypes.h"

// Vertex shader outputs and fragment shader inputs
struct RasterizerData
{
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];

    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    float4 color;
};

vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
             constant AAPLVertex *vertices [[buffer(AAPLVertexInputIndexVertices)]],
             constant float3x3 *transformationMatrix [[buffer(DanVertexInputIndexTransformationMatrix)]],
             constant uint2 *viewportSizePointer [[buffer(AAPLVertexInputIndexViewportSize)]])
{
    RasterizerData out;

    // Index into the array of positions to get the current vertex.
    // The positions are specified in pixel dimensions (i.e. a value of 100
    // is 100 pixels from the origin).
    float3 pixelSpacePosition = vertices[vertexID].position.xyz;
//    pixelSpacePosition = pixelSpacePosition * *transformationMatrix;
    
    // Apply transformation matrix to pixelSpacePosition
    float3 clipSpacePosition = float3(pixelSpacePosition);
//    clipSpacePosition.z = 1;
    clipSpacePosition = clipSpacePosition * float3x3(*transformationMatrix);
    
//    float3x3 mat = float3x3(*transformationMatrix);
//    clipSpacePosition.x = clipSpacePosition.x * mat[0][0] + clipSpacePosition.y * mat[1][0] + clipSpacePosition.z * mat[2][0];
//    clipSpacePosition.y = clipSpacePosition.x * mat[1][0] + clipSpacePosition.y * mat[1][1] + clipSpacePosition.z * mat[1][2];
//    clipSpacePosition.z = clipSpacePosition.x * mat[2][0] + clipSpacePosition.y * mat[2][1] + clipSpacePosition.z * mat[2][2];
    
    

    // Convert clip space position to normalized device coordinates (NDC)
    out.position.xy = clipSpacePosition.xy / clipSpacePosition.z;

    // Get the viewport size and cast to float.
    float2 viewportSize = float2(*viewportSizePointer);
    
    out.position.xy = clipSpacePosition.xy / (viewportSize / 2);

    // Pass the input color directly to the rasterizer.
    out.color = vertices[vertexID].color;

    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               constant float *timePointer [[buffer(3)]])
{
    return in.color;
}
