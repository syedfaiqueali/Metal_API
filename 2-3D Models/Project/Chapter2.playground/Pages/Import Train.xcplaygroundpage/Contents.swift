import PlaygroundSupport
import MetalKit

guard let device = MTLCreateSystemDefaultDevice() else {
  fatalError("GPU is not supported")
}

let frame = CGRect(x: 0, y: 0, width: 500, height: 500)
let view = MTKView(frame: frame, device: device)
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)
view.device = device

let allocator = MTKMeshBufferAllocator(device: device)
/*
let mdlMesh = MDLMesh(coneWithExtent: [1, 1, 1],
                      segments: [10, 10],
                      inwardNormals: false,
                      cap: true,
                      geometryType: .triangles,
                      allocator: allocator)
 */
//MARK:- Setup the url file for the model
guard let assetURL = Bundle.main.url(forResource: "train", withExtension: "obj") else {
    fatalError()
}

//MARK:- Vertex Descriptors
//1 - create descriptor config. all the properties
let vertexDescriptor = MTLVertexDescriptor()

//2 - tell descriptor that xyz position data should load as float3
vertexDescriptor.attributes[0].format = .float3

//3 - offest specifies where in the buffer this particular data will start
vertexDescriptor.attributes[0].offset = 0

//4 - specifying the bufferIndex out of 31 buffers
vertexDescriptor.attributes[0].bufferIndex = 0


//1 - Specify stride(No of bytes btw each set of vertex info) for buffer 0
vertexDescriptor.layouts[0].stride = MemoryLayout<float3>.stride
//2 - create new Model I/O descriptor from the vertex descriptor
let meshDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
//3 - Assign a string name 'position' to the attribute, tell model about positional data.
(meshDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition


//Reads the asset using the URL, vertex desc. and memory allocator.
let asset = MDLAsset (url: assetURL,
                       vertexDescriptor: meshDescriptor,
                       bufferAllocator: allocator)

let mdlMesh = asset.object(at: 0) as! MDLMesh

let mesh = try MTKMesh(mesh: mdlMesh, device: device)

guard let commandQueue = device.makeCommandQueue() else {
  fatalError("Could not create a command queue")
}

let shader = """
#include <metal_stdlib> \n
using namespace metal;

struct VertexIn {
  float4 position [[ attribute(0) ]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
  return vertex_in.position;
}

fragment float4 fragment_main() {
  return float4(1, 0, 0, 1);
}
"""

let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

let pipelineDescriptor = MTLRenderPipelineDescriptor()
pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
pipelineDescriptor.vertexFunction = vertexFunction
pipelineDescriptor.fragmentFunction = fragmentFunction
pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

guard let commandBuffer = commandQueue.makeCommandBuffer(),
  let renderPassDescriptor = view.currentRenderPassDescriptor,
  let renderEncoder =
  commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
  else { fatalError() }

renderEncoder.setRenderPipelineState(pipelineState)
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer,
                              offset: 0, index: 0)

renderEncoder.setTriangleFillMode(.lines)

/*
guard let submesh = mesh.submeshes.first else {
  fatalError()
}
renderEncoder.drawIndexedPrimitives(type: .triangle,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer,
                                    indexBufferOffset: 0)
 */
for submesh in mesh.submeshes {
    renderEncoder.drawIndexedPrimitives(type: .triangle,
                                        indexCount: submesh.indexCount,
                                        indexType: submesh.indexType,
                                        indexBuffer: submesh.indexBuffer.buffer,
                                        indexBufferOffset: submesh.indexBuffer.offset)
}

renderEncoder.endEncoding()
guard let drawable = view.currentDrawable else {
  fatalError()
}
commandBuffer.present(drawable)
commandBuffer.commit()

PlaygroundPage.current.liveView = view
