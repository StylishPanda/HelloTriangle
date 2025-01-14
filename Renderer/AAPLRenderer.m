/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of a platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import simd;
@import MetalKit;

#import "AAPLRenderer.h"

// Header shared between C code here, which executes Metal API commands, and .metal files, which
// uses these types as inputs to the shaders.
#import "AAPLShaderTypes.h"

// Main class performing the rendering
@implementation AAPLRenderer
{
    id<MTLDevice> _device;

    // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
    id<MTLRenderPipelineState> _pipelineState;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;

    // The current size of the view, used as an input to the vertex shader.
    simd_uint2 _viewportSize;
}

-(simd_float3x3) translationMatrix: (float)tx ty:(float)ty {
    simd_float3x3 translationMatrix = matrix_identity_float3x3;
    translationMatrix.columns[0].z = tx;
    translationMatrix.columns[1].z = ty;
    
    return translationMatrix;
}

-(simd_float3x3) rotationMatrix: (float)angle {
    simd_float3x3 rotationMatrix = matrix_identity_float3x3;
    float angleInRadians = [self toRadians:angle];
    rotationMatrix.columns[0].x = cos(angleInRadians);
    rotationMatrix.columns[0].y = -sin(angleInRadians);
    rotationMatrix.columns[1].x = sin(angleInRadians);
    rotationMatrix.columns[1].y = cos(angleInRadians);
    
    return rotationMatrix;
}

-(float)toRadians: (float)degrees {
    return M_PI * degrees / 180;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        NSError *error;

        _device = mtkView.device;

        // Load all the shader files with a .metal file extension in the project.
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

        // Configure a pipeline descriptor that is used to create a pipeline state.
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Simple Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;

        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
                
        // Pipeline State creation could fail if the pipeline descriptor isn't set up properly.
        //  If the Metal API validation is enabled, you can find out more information about what
        //  went wrong.  (Metal API validation is enabled by default when a debug build is run
        //  from Xcode.)
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);

        // Create the command queue
        _commandQueue = [_device newCommandQueue];
    }

    return self;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Save the size of the drawable to pass to the vertex shader.
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

/// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
    AAPLVertex triangleVertices[] =
    {
        // 2D positions,    RGBA colors
        { {  0,  250, 1 }, { 1, 0, 0, 1 } },
        { { 250,  0, 1 }, { 0, 1, 0, 1 } },
        { {    0,   0, 1 }, { 0, 0, 1, 1 } },

        { {  0,  250, 1 }, { 1, 0, 0, 1 } },
        { { 250,   250, 1 }, { 0, 1, 0, 1 } },
        { {  250,   0, 1 }, { 0, 0, 1, 1 } },
    };
    
    static const int length = sizeof(triangleVertices) / sizeof(triangleVertices[0]);
    simd_float3x3 translationMatrix = [self translationMatrix:-125 ty:-125];
    simd_float3x3 rotationMatrix = [self rotationMatrix:45];
    simd_float3x3 transformationMatrix = matrix_multiply(translationMatrix, rotationMatrix);

    // Create a new command buffer for each render pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder.
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0 }];
        
        [renderEncoder setRenderPipelineState:_pipelineState];

        // Pass in the parameter data.
        [renderEncoder setVertexBytes:triangleVertices
                               length:sizeof(triangleVertices)
                              atIndex:AAPLVertexInputIndexVertices];
        
        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];
        
        [renderEncoder setVertexBytes:&transformationMatrix
                            length:sizeof(transformationMatrix)
                              atIndex:DanVertexInputIndexTransformationMatrix];
        
        NSDate *date = [[NSDate alloc] init];
        float timePassedNormalized = date.timeIntervalSince1970;
        
        [renderEncoder setFragmentBytes:&timePassedNormalized
                                 length:sizeof(float)
                                atIndex:3];

        // Draw the triangle.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount: 6];

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit];
}

@end
