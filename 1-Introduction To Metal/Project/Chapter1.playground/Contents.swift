import PlaygroundSupport
import MetalKit


//MARK:- Check for a suitable device by creating a device
guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("GPU is not supported")
}

//MARK:- Setup the view
let frame = CGRect(x: 0, y: 0, width: 200, height: 200)

//MKView -subclass of NSView
let view = MTKView(frame: frame, device: device)

//MTLClearColor - represent RGBA value
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)


//MARK:- The Model
//1- allocator manages the memory for the mesh data
let allocator = MTKMeshBufferAllocator(device: device)

//2- Model I/O creates a sphere with the specified size and returns a MDLMesh
//   with vertex information in buffers
let mdlMesh = MDLMesh(
    sphereWithExtent: [0.75,0.75,0.2],
    segments: [100,100],
    inwardNormals: false,
    geometryType: .triangles,
    allocator: allocator)

//3- Convert Model I/O mesh to a MetalKit
let mesh = try MTKMesh(mesh: mdlMesh, device: device)


//Create a command Queue
guard let commandQueue = device.makeCommandQueue() else {
    fatalError("Could not create a command queue.")
}

/**Shader func are small program run on the GPU
    2 shader functions here:
     i) vertex func (vertex_main), where we usually manipulate vertex positions.
     ii) fragment func (fragment_main), where we specify the pixel color.
 */
let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float4 position [[ attribute(0) ]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
  return vertex_in.position;
}

fragment float4 fragment_main() {
  return float4(0,0.4,0.21,1);
}
"""

//MARK:- Setup Metal Library
let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")


//MARK:- The Pipeline State
/**Setup descriptor with the correct shader func and a vertex descriptor.
   Vertex descriptor describes how the vertices are laid out in a Metal Buffer.
   Model I/O automatically create a vertex descriptor when it loaded the sphere mesh.*/
let descriptor = MTLRenderPipelineDescriptor()
descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
descriptor.vertexFunction = vertexFunction
descriptor.fragmentFunction = fragmentFunction
descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

// Create the Pipeline state from the descriptor
let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)


//MARK:- Rendering
// commandBuffer - stores all command that you'll ask GPU to run
guard let commandBuffer = commandQueue.makeCommandBuffer(),
      //descriptor - holds data for a number of render destinations
      let descriptor = view.currentRenderPassDescriptor,
      //renderEncoder - holds all the info necc. to send to the GPU, to draw vertices.
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
else { fatalError() }

//Give renderEncoder the pipeline state
renderEncoder.setRenderPipelineState(pipelineState)
//Give earlier loaded sphere mesh to renderEncoder
renderEncoder.setVertexBuffer(
    mesh.vertexBuffers[0].buffer,
    offset: 0,
    index: 0)

guard let submesh = mesh.submeshes.first else {
    fatalError()
}

// Instructing GPU to render a vertex buffer consisting of triangles with
// the vertices placed in the correct order by the submesh index info.
renderEncoder.drawIndexedPrimitives(
    type: .triangle,
    indexCount: submesh.indexCount,
    indexType: submesh.indexType,
    indexBuffer: submesh.indexBuffer.buffer,
    indexBufferOffset: 0)

// Tell renderEncoder that there are no more draw cells
renderEncoder.endEncoding()

//
guard let drawable = view.currentDrawable else {fatalError()}

// commandBuffer to present the MTKView's drawable & commit to the GPU
commandBuffer.present(drawable)
commandBuffer.commit()

PlaygroundPage.current.liveView = view

