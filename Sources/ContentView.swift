import SwiftUI
// import MetalKit
import Metal
import simd
import Foundation
struct ContentView: View {
    var timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    @State private var cplayer = player(position: CGPoint(x: 0, y: 0), velocity: CGPoint(x: 0, y: 0), mass: 1, radius: 10)
    @State private var nodes: [node] = []
    var body: some View {
        GeometryReader{ geo in
        ZStack{
            VStack{
                HStack{
                    Canvas() { context, size in
                        for node in nodes {
                            context.fill(Path(ellipseIn: CGRect(x: node.position.x - 5 - cplayer.position.x + size.width/2, y: node.position.y - 5 - cplayer.position.x + size.height/2, width: 10, height: 10)), with: .color(.red))
                        }
                        context.fill(Path(ellipseIn: CGRect(x: cplayer.position.x - 5 + size.width/2, y: cplayer.position.y - 5 + size.height/2, width: 10, height: 10)), with: .color(.blue))
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onTapGesture { pos in
                        nodes.append(node(position: pos + cplayer.position - CGPoint(x: geo.size.width/2, y: geo.size.height/2)))
                    }
                    .focusable()
                    .onKeyPress(keys: [.downArrow, .upArrow, .leftArrow, .rightArrow]) { KeyPress in
                        switch KeyPress.key {
                        case .downArrow:
                            cplayer.velocity.y = 1
                        case .upArrow:
                            cplayer.velocity.y = -1
                        case .leftArrow:
                            cplayer.velocity.x = -1
                        case .rightArrow:
                            cplayer.velocity.x = 1
                        default:
                            break
                        }
                        return .handled
                    }
                }
            }
        }
        }
    }
}
class node: Identifiable {
    var id = UUID()
    var position: CGPoint
    var connections: [connection] = []
    var velocity:CGPoint {
        let v1k = connections.map { connection -> CGPoint in
    let startPosition = connection.start.position
    let endPosition = connection.end.position
    let otherPosition = startPosition == position ? endPosition : startPosition
    let vector = position - otherPosition
    let idealLength = connection.idealLength
    let scaledVector = vector * (hypot(vector.x, vector.y) - idealLength)
    return scaledVector
}
        let v1 = v1k.reduce(CGPoint.zero, +)*0.8;
        let v2 = pvelocity * 0.2;
        pvelocity = CGPoint(x: v1.x + v2.x, y: v1.y + v2.y)
        return pvelocity
    }
    var pvelocity: CGPoint = .zero
    init(position: CGPoint) {
        self.position = position
    }
    deinit {
        connections.forEach { $0.end.connections.removeAll { $0.id == $0.id } }
    }
}
func *(point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

// Helper operator to add two CGPoints
func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}
class connection: Identifiable {
    var id = UUID()
    var start: node
    var end: node
    var idealLength: CGFloat
    var stress: CGFloat {
        let k = (start.position - end.position)
        let distance = hypot(k.x, k.y)
        return (distance - idealLength) / idealLength
    }
    init(start: node, end: node, idealLength: CGFloat) {
        self.start = start
        self.end = end
        self.idealLength = idealLength
    }
    deinit {
        start.connections.removeAll { $0.id == id }
        end.connections.removeAll { $0.id == id }
    }
}
func collisionTransfer(n1Velocity: CGPoint, n2Velocity: CGPoint, n1Mass: CGFloat, n2Mass: CGFloat) -> (CGPoint, CGPoint) {
let totalMass = n1Mass + n2Mass
let n1newvelocityx = (n1Velocity.x * (n1Mass - n2Mass) + 2 * n2Mass * n2Velocity.x) / totalMass
let n1newvelocityy = (n1Velocity.y * (n1Mass - n2Mass) + 2 * n2Mass * n2Velocity.y) / totalMass
let n2newvelocityx = (n2Velocity.x * (n2Mass - n1Mass) + 2 * n1Mass * n1Velocity.x) / totalMass
let n2newvelocityy = (n2Velocity.y * (n2Mass - n1Mass) + 2 * n1Mass * n1Velocity.y) / totalMass
let n1newVelocity = CGPoint(x: n1newvelocityx, y: n1newvelocityy)
let n2newVelocity = CGPoint(x: n2newvelocityx, y: n2newvelocityy)
return (n1newVelocity, n2newVelocity)
}

struct player: Identifiable{
    var id: UUID
    var position: CGPoint
    var velocity: CGPoint
    var mass: CGFloat
    var radius: CGFloat
    var centerofmassOffset: CGPoint
    init(position: CGPoint, velocity: CGPoint, mass: CGFloat, radius: CGFloat, id: UUID = UUID(), centerofmassOffset: CGPoint = .zero) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.mass = mass
        self.radius = radius
        self.centerofmassOffset = centerofmassOffset
    }

}

struct Circle {
    var position: SIMD2<Float>
    var radius: Float
}

struct CollisionPair {
    var index1: UInt32
    var index2: UInt32
}

func detectCollisions(circles: [Circle]) -> [[Int]] {
    // Step 1: Set up Metal
    guard let device = MTLCreateSystemDefaultDevice(),
          let commandQueue = device.makeCommandQueue(),
          let library = device.makeDefaultLibrary(),
          let kernelFunction = library.makeFunction(name: "detectCollisions"),
          let pipelineState = try? device.makeComputePipelineState(function: kernelFunction) else {
        fatalError("Unable to set up Metal")
    }

    // Step 2: Prepare data
    let circleCount = circles.count
    let maxPairs = circleCount * (circleCount - 1) / 2 // Maximum possible pairs

    let collisionPairs = [CollisionPair](repeating: CollisionPair(index1: 0, index2: 0), count: maxPairs)
    var pairCount: UInt32 = 0

    let circleBuffer = device.makeBuffer(bytes: circles, length: MemoryLayout<Circle>.size * circleCount, options: [])
    let collisionPairBuffer = device.makeBuffer(bytes: collisionPairs, length: MemoryLayout<CollisionPair>.size * maxPairs, options: [])
    let pairCountBuffer = device.makeBuffer(bytes: &pairCount, length: MemoryLayout<UInt32>.size, options: [])

    // Step 3: Create command buffer and encoder
    guard let commandBuffer = commandQueue.makeCommandBuffer(),
          let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
        fatalError("Unable to create command buffer or encoder")
    }

    // Step 4: Set buffers and pipeline state
    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setBuffer(circleBuffer, offset: 0, index: 0)
    computeEncoder.setBuffer(collisionPairBuffer, offset: 0, index: 1)
    computeEncoder.setBuffer(pairCountBuffer, offset: 0, index: 2)

    // Step 5: Dispatch threads
    let gridSize = MTLSize(width: circleCount, height: 1, depth: 1)
    let threadGroupSize = MTLSize(width: min(pipelineState.maxTotalThreadsPerThreadgroup, circleCount), height: 1, depth: 1)
    computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)

    // Step 6: End encoding and commit command buffer
    computeEncoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    // Step 7: Retrieve results
    let pairCountPointer = pairCountBuffer?.contents().bindMemory(to: UInt32.self, capacity: 1)
    let collisionPairPointer = collisionPairBuffer?.contents().bindMemory(to: CollisionPair.self, capacity: Int(pairCountPointer!.pointee))

    let collisionPairsArray = Array(UnsafeBufferPointer(start: collisionPairPointer, count: Int(pairCountPointer!.pointee)))
    let results = collisionPairsArray.map { [Int($0.index1), Int($0.index2)] }

    return results
}