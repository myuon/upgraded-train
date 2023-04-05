include("image.jl")

kEPS = 1e-6

import Base: +
import Base: -
import Base: *

struct Vec3
    data::Vector{Float64}

    function Vec3(x::Number, y::Number, z::Number)
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
    color::RGB
end

struct HitRecord
    point::Vec3
    normal::UnitVec3
    distance::Float64
end

function hit(sphere::Sphere, ray::Ray)::Union{HitRecord,Nothing}
    oc = ray.origin - sphere.center
    a = dot(ray.direction, ray.direction)
    b = 2 * dot(oc, ray.direction)
    c = dot(oc, oc) - sphere.radius^2
    discriminant = b^2 - 4 * a * c

    if discriminant < 0
        return nothing
    end

    t1 = (-b + sqrt(discriminant)) / (2 * a)
    t2 = (-b - sqrt(discriminant)) / (2 * a)
    if t1 < kEPS && t2 < kEPS
        return nothing
    end

    if t1 < kEPS
        distance = t2
    else
        distance = t1
    end

    return HitRecord(
        ray.origin + (-b - sqrt(discriminant)) / (2 * a) * ray.direction,
        normalize(ray.origin + (-b - sqrt(discriminant)) / (2 * a) * ray.direction - sphere.center),
        distance,
    )
end

function sample_lambertian_cosine_pdf(ray::Ray, normal::UnitVec3)::UnitVec3
    w = normal
    u = normalize(cross(Vec3(0, 1, 0), w))
    v = cross(w, u)

    phy = 2π * rand()
    cos_theta = sqrt(rand())

    normalize(
        u * cos(phy) * cos_theta +
        v * sin(phy) * cos_theta +
        w * sqrt(1 - cos_theta^2)
    )
end

struct Scene
    camera::Camera
    objects::Vector{Sphere}
end

function hit_in_scene(scene::Scene, ray::Ray)::Union{Tuple{HitRecord,Sphere},Nothing}
    for object in scene.objects
        hr = hit(object, ray)
        if !isnothing(hr)
            return hr, object
        end
    end

    return nothing
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

                hr = hit_in_scene(scene, ray)
                while !isnothing(hr)
                    result.data[i, j] += hr[2].color

                    ray = Ray(hr[1].point, sample_lambertian_cosine_pdf(ray, hr[1].normal))
                    hr = hit_in_scene(scene, ray)

                    if rand() < 0.5
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
        [Sphere(Vec3(50.0, 90.0, 81.6), 15.0, RGB(255, 128, 0)), Sphere(Vec3(77.0, 16.5, 78.0), 16.5, RGB(0, 0, 255))],
    )

    result = render(scene, (500, 500))

    save("output", result)
end

main()
