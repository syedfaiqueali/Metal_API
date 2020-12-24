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

import MetalKit

class Renderer: NSObject {
    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var library: MTLLibrary!
    static var colorPixelFormat: MTLPixelFormat!
    
    var uniforms = Uniforms()
    var fragmentUniforms = FragmentUniforms()
    let depthStencilState: MTLDepthStencilState
    let lighting = Lighting()
    
    //Proceduaral animations
    var currentTime: Float = 0
    
    //animation using physics
    var ballVeclocity: Float = 0
    
    //For squash and stretch
    var maxVelocity: Float = 0
    
    lazy var camera: Camera = {
        let camera = ArcballCamera()
        camera.distance = 3
        camera.target = [0, 1.3, 0]
        camera.rotation.x = Float(-15).degreesToRadians
        return camera
    }()
    
    // Array of Models allows for rendering multiple models
    var models: [Model] = []
    
    init(metalView: MTKView) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            fatalError("GPU not available")
        }
        Renderer.device = device
        Renderer.commandQueue = commandQueue
        Renderer.library = device.makeDefaultLibrary()
        Renderer.colorPixelFormat = metalView.colorPixelFormat
        metalView.device = device
        metalView.depthStencilPixelFormat = .depth32Float
        
        depthStencilState = Renderer.buildDepthStencilState()!
        super.init()
        metalView.clearColor = MTLClearColor(red: 0.49, green: 0.62,
                                             blue: 0.75, alpha: 1)
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        
        // models
        let ball = Model(name: "beachball.usda")
        ball.position = [0, 3, 0]
        ball.scale = [100, 100, 100]
        models.append(ball)
        let ground = Model(name: "ground.obj")
        ground.scale = [100, 100, 100]
        models.append(ground)
        
        fragmentUniforms.lightCount = lighting.count
    }
    
    
    static func buildDepthStencilState() -> MTLDepthStencilState? {
        // 1
        let descriptor = MTLDepthStencilDescriptor()
        // 2
        descriptor.depthCompareFunction = .less
        // 3
        descriptor.isDepthWriteEnabled = true
        return
            Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        camera.aspect = Float(view.bounds.width)/Float(view.bounds.height)
    }
    
    func draw(in view: MTKView) {
        guard
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let renderEncoder =
                commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        let deltaTime = 1 / Float(view.preferredFramesPerSecond)
        update(deltaTime: deltaTime)
        
        renderEncoder.setDepthStencilState(depthStencilState)
        
        uniforms.projectionMatrix = camera.projectionMatrix
        uniforms.viewMatrix = camera.viewMatrix
        fragmentUniforms.cameraPosition = camera.position
        
        var lights = lighting.lights
        renderEncoder.setFragmentBytes(&lights,
                                       length: MemoryLayout<Light>.stride * lights.count,
                                       index: Int(BufferIndexLights.rawValue))
        
        // render all the models in the array
        for model in models {
            renderEncoder.pushDebugGroup(model.name)
            model.render(renderEncoder: renderEncoder,
                         uniforms: uniforms,
                         fragmentUniforms: fragmentUniforms)
            renderEncoder.popDebugGroup()
        }
        
        renderEncoder.endEncoding()
        guard let drawable = view.currentDrawable else {
            return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    //To update objects everyframe
    func update(deltaTime: Float) {
        currentTime += deltaTime * 4
        let ball = models[0]
        //ball.position.x = sin(currentTime)
        let gravity: Float = 9.8
        let mass: Float = 0.05
        let acceleration = gravity/mass  //F=ma => a=F(gravity)/m
        let airFriction: Float = 0.2
        let bounciness: Float = 0.9
        let timeStep: Float = 1/600
        
        /**Calculate the position of the ball based on the ball's cuurent velocity.
         The ball's origin is in the center, approx 0.7 units in diameter, so when
         ball's center is 0.35 units above the ground, that's when you reverse the
         velocity and travel upward.*/
        ballVeclocity += (acceleration * timeStep) / airFriction
        maxVelocity = max(maxVelocity, abs(ballVeclocity))
        
        ball.position.y -= ballVeclocity * timeStep
        
        if ball.position.y <= ball.size.y/2 {  //collision with ground
            ball.position.y = ball.size.y/2
            ballVeclocity = ballVeclocity * -1 * bounciness
            
            //depending on ball's velocity, squash the ball on y-axis & to maintain mass of ball expand ball on x and z axis
            ball.scale.y = max(0.5, 1 - 0.8 * abs(ballVeclocity) / maxVelocity)
            ball.scale.z = 1 + (1 - ball.scale.y) / 2
            ball.scale.x = ball.scale.z
        }
        
        //After hitting, when ball head's back up, increase size again
        if ball.scale.y < 1{
            let change: Float = 0.07
            ball.scale.y += change
            ball.scale.z -= change / 2
            ball.scale.x = ball.scale.z
            if ball.scale.y > 1 {
                ball.scale = [1,1,1]
            }
        }
    }
}
