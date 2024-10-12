#include <metal_stdlib>
using namespace metal;

struct Circle {
    float2 position;
    float radius;
};

struct CollisionPair {
    uint index1;
    uint index2;
};

kernel void detectCollisions(
    device const Circle* circles [[buffer(0)]],
    device CollisionPair* collisionPairs [[buffer(1)]],
    device uint* pairCount [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    uint circleCount = circles->length;
    uint localPairCount = 0;

    for (uint i = 0; i < circleCount; ++i) {
        if (i != index) {
            float2 diff = circles[index].position - circles[i].position;
            float distanceSquared = dot(diff, diff);
            float radiusSum = circles[index].radius + circles[i].radius;
            if (distanceSquared < (radiusSum * radiusSum)) {
                uint currentIndex = atomic_fetch_add(pairCount, 1);
                collisionPairs[currentIndex] = CollisionPair{index, i};
            }
        }
    }
}