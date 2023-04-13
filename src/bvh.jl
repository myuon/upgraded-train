module BVH

using ...Vectors
using ...Shapes

struct AABB
    min::Vec3
    max::Vec3

    function AABB(min::Vec3, max::Vec3)
        return new(min, max)
    end
end

function merge(a::AABB, b::AABB)::AABB
    return AABB(
        Vec3(min(a.min.x, b.min.x), min(a.min.y, b.min.y), min(a.min.z, b.min.z)),
        Vec3(max(a.max.x, b.max.x), max(a.max.y, b.max.y), max(a.max.z, b.max.z)),
    )
end

function AABB(triangles::Vector{Triangle})::AABB
    min = Vec3(Inf, Inf, Inf)
    max = Vec3(-Inf, -Inf, -Inf)

    for triangle in triangles
        vs = vertices_triangle(triangle)

        for vertex in vs
            min = Vec3(min(min.x, vertex.x), min(min.y, vertex.y), min(min.z, vertex.z))
            max = Vec3(max(max.x, vertex.x), max(max.y, vertex.y), max(max.z, vertex.z))
        end
    end

    return AABB(min, max)
end

function emptyAABB()::AABB
    return AABB(Vec3(Inf, Inf, Inf), Vec3(-Inf, -Inf, -Inf))
end

struct BVHNode
    bbox::AABB
    triangles::Vector{Triangle}
    left::Union{BVHNode,Nothing}
    right::Union{BVHNode,Nothing}
end

struct BVHTree
    root::BVHNode
end

# この辺は適当
const T_tri = 1
const T_aabb = 1

function BVHTree(triangles::Vector{Triangle})::BVHTree
    box = AABB(triangles)
    cost = T_tri * length(triangles)
    splitAxis = nothing
    splitIndex = nothing

    triangles = triangles[1:end]

    for axis in 1:3
        sorted = sort!(triangles, by=t -> center(t)[axis])

        s1surfaces = Vector{Float64}()
        s2surfaces = Vector{Float64}()

        s1box = emptyAABB()
        s2box = emptyAABB()
        for i in 1:length(triangles)
            push!(s1surfaces, area_size(AABB(sorted[1:i])))
        end
    end
end

end
