import MetalKit
import PlaygroundSupport

//MARK:- Set up View
device = MTLCreateSystemDefaultDevice()!
let frame = NSRect(x: 0, y: 0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device)
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)
view.device = device

// Metal set up is done in Utility.swift

//MARK:- Set up render pass
guard let drawable = view.currentDrawable,
  let descriptor = view.currentRenderPassDescriptor,
  let commandBuffer = commandQueue.makeCommandBuffer(),
  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
    fatalError()
}
renderEncoder.setRenderPipelineState(pipelineState)

//MARK:- Drawing code here
//vertex position which is at the center of the screen
var vertices = [float3(0,0,0.5)]

//Create the Metal Buffer containing vertices
let originalBuffer = device.makeBuffer(bytes: &vertices,
                                       length: MemoryLayout<float3>.stride * vertices.count,
                                       options: [])

//Setup the Buffers for the vertex and fragment functions
renderEncoder.setVertexBuffer(originalBuffer, offset: 0, index: 0)
renderEncoder.setFragmentBytes(&lightGrayColor, length: MemoryLayout<float4>.stride, index: 0)

//draw
renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertices.count)

vertices[0].x += 0.3
vertices[0].y -= 0.4
var transformedBuffer = device.makeBuffer(bytes: &vertices, length: MemoryLayout<float3>.stride * vertices.count, options: [])

//Setup the Buffers for the vertex and fragment functions
renderEncoder.setVertexBuffer(transformedBuffer, offset: 0, index: 0)
renderEncoder.setFragmentBytes(&redColor, length: MemoryLayout<float4>.stride, index: 0)

//draw
renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertices.count)


renderEncoder.endEncoding()
commandBuffer.present(drawable)
commandBuffer.commit()

PlaygroundPage.current.liveView = view
