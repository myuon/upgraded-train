include("image.jl")

import Base: +
import Base: -
import Base: *

struct Vec3
    data::Vector{Float64}

    function Vec3(x::Float64, y::Float64, z::Float64)
        new([x, y, z])
    end

    function Vec3(vec::Vector{Float64})
        @assert Base.length(vec) == 3

        new(vec)
    end
end

as_vector(v::Vec3)::Vector{Float64} = v.data

length(v::Vec3)::Float64 = sqrt(sum(v.data .^ 2))

normalize(v::Vec3)::UnitVec3 = UnitVec3(Vec3(v.data ./ length(v)))

dot(v1::Vec3, v2::Vec3)::Float64 = sum(v1.data .* v2.data)

cross(v1::Vec3, v2::Vec3)::Vec3 = Vec3(
    v1.data[2] * v2.data[3] - v1.data[3] * v2.data[2],
    v1.data[3] * v2.data[1] - v1.data[1] * v2.data[3],
    v1.data[1] * v2.data[2] - v1.data[2] * v2.data[1],
)

+(v1::Vec3, v2::Vec3)::Vec3 = Vec3(v1.data .+ v2.data)

-(v1::Vec3, v2::Vec3)::Vec3 = Vec3(v1.data .- v2.data)

*(v::Vec3, s::Number)::Vec3 = Vec3(s * v.data)

*(s::Number, v::Vec3)::Vec3 = Vec3(s * v.data)

struct UnitVec3
    data::Vector{Float64}

    function UnitVec3(x::Float64, y::Float64, z::Float64)
        @assert sqrt(x^2 + y^2 + z^2) - 1 < 1e-6

        new([x, y, z])
    end

    function UnitVec3(vec::Vec3)
        @assert length(vec) - 1 < 1e-6

        new(vec.data)
    end
end

as_vector(v::UnitVec3)::Vector{Float64} = v.data

as_vec3(v::UnitVec3)::Vec3 = Vec3(v.data)

normalize(v::UnitVec3)::UnitVec3 = v

dot(v1::UnitVec3, v2::UnitVec3)::Float64 = sum(v1.data .* v2.data)

dot(v1::UnitVec3, v2::Vec3)::Float64 = sum(v1.data .* v2.data)

dot(v1::Vec3, v2::UnitVec3)::Float64 = sum(v1.data .* v2.data)

cross(v1::UnitVec3, v2::UnitVec3)::UnitVec3 = UnitVec3(
    v1.data[2] * v2.data[3] - v1.data[3] * v2.data[2],
    v1.data[3] * v2.data[1] - v1.data[1] * v2.data[3],
    v1.data[1] * v2.data[2] - v1.data[2] * v2.data[1],
)

cross(v1::UnitVec3, v2::Vec3)::Vec3 = cross(as_vec3(v1), v2)

cross(v1::Vec3, v2::UnitVec3)::Vec3 = cross(v1, as_vec3(v2))

*(v::UnitVec3, s::Number)::Vec3 = Vec3(s * v.data)

*(s::Number, v::UnitVec3)::Vec3 = Vec3(s * v.data)

struct Ray
    origin::Vec3
    direction::UnitVec3
end

struct Camera
    origin::Vec3
    up::UnitVec3
    direction::UnitVec3
    screendist::Float64
end

struct Sphere
    center::Vec3
    radius::Float64
end

function hit(sphere::Sphere, ray::Ray)::Bool
    oc = ray.origin - sphere.center
    a = dot(ray.direction, ray.direction)
    b = 2 * dot(oc, ray.direction)
    c = dot(oc, oc) - sphere.radius^2
    discriminant = b^2 - 4 * a * c

    discriminant > 0
end

struct Scene
    camera::Camera
    objects::Vector{Sphere}
end

function render(scene::Scene, size::Tuple{Int,Int})::Image
    result = Image(size)
    spp = 1

    screenx = normalize(cross(scene.camera.direction, scene.camera.up))
    screeny = normalize(cross(screenx, scene.camera.direction))
    screencenter = scene.camera.origin + scene.camera.direction * scene.camera.screendist

    for _ in 1:spp
        for i in 1:size[1]
            for j in 1:size[2]
                screenp = screencenter + (i - size[1] / 2) * screenx + (j - size[2] / 2) * screeny
                ray = Ray(screenp, normalize(screenp - scene.camera.origin))

                for object in scene.objects
                    if hit(object, ray)
                        result.data[i, j] = RGB(55, 55, 55)
                        break
                    end
                end
            end
        end
    end

    for i in 1:size[1]
        for j in 1:size[2]
            result.data[i, j] = result.data[i, j] / spp
        end
    end

    result
end

function main()
    scene = Scene(
        Camera(Vec3(50.0, 52.0, 220.0), normalize(Vec3(0.0, 1.0, 0.0)), normalize(Vec3(0.0, -0.04, -1.0)), 40.0),
        [Sphere(Vec3(50.0, 90.0, 81.6), 15.0), Sphere(Vec3(77.0, 16.5, 78.0), 16.5)],
    )

    result = render(scene, (100, 100))

    save("output", result)
end

main()
