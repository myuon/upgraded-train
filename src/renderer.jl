module Renderers

using ...Vectors
using ...Images
using ...Loaders
using ...Shapes
using ...Rays

struct Camera
    origin::Vec3
    up::UnitVec3
    direction::UnitVec3
    screendist::Float64
end

struct Scene
    camera::Camera
    screensize::Int
    meshes::Vector{Mesh}
end

function hit_in_scene(scene::Scene, ray::Ray)::Union{Tuple{HitRecord,Mesh},Nothing}
    distance = Inf
    result = nothing

    for mesh in scene.meshes
        hr = hit(mesh, ray)
        if !isnothing(hr) && hr.distance < distance
            result = hr, mesh
            distance = hr.distance
        end
    end

    return result
end

function sample_on_light(scene::Scene)::Tuple{Mesh,Tuple{Vec3,UnitVec3}}
    sample_count = 0
    for mesh in scene.meshes
        if is_light(mesh)
            sample_count += 1
        end
    end

    light_index = rand(1:sample_count)

    sample_count = 0
    for mesh in scene.meshes
        if is_light(mesh)
            sample_count += 1
            if sample_count == light_index
                return mesh, sample_on(mesh)
            end
        end
    end
end

const russian_roulette_min = 5
const russian_roulette_max = 10

function render(
    scene::Scene,
    size::Tuple{Int,Int},
    spp::Int,
    enable_NEE::Bool,
    enable_DEBUG_HIT_NORMAL::Bool,
)::Image
    result = Image(size)

    screenx = normalize(cross(scene.camera.direction, scene.camera.up)) * Float64(scene.screensize)
    screeny = normalize(cross(screenx, scene.camera.direction)) * (scene.screensize / size[1] * size[2])
    screencenter = scene.camera.origin + scene.camera.direction * scene.camera.screendist

    Threads.@threads for i in 1:size[1]
        Threads.@threads for j in 1:size[2]
            for _ in 1:spp
                screenp = screencenter + ((i + rand()) / size[1] - 0.5) * screenx - ((j + rand()) / size[2] - 0.5) * screeny
                ray = Ray(screenp, normalize(screenp - scene.camera.origin))
                weight = 1.0
                count = 0

                prev_nee_contributed = false
                hr = hit_in_scene(scene, ray)
                if isnothing(hr)
                    result.data[i, j] += RGB(0.5, 0.5, 0.5)
                    continue
                end
                while !isnothing(hr)
                    count += 1
                    ht, object = hr
                    orientnormal = dot(ht.normal, ray.direction) < 0 ? ht.normal : -ht.normal

                    if enable_DEBUG_HIT_NORMAL
                        result.data[i, j] += RGB((x(ht.normal) + 1.0) / 2.0, (y(ht.normal) + 1.0) / 2.0, (z(ht.normal) + 1.0) / 2.0)
                        break
                    end

                    if !enable_NEE || !prev_nee_contributed
                        result.data[i, j] += object.emit * weight
                    end
                    if enable_NEE && object.reflection == diffuse
                        light, (lightp, lightnormal) = sample_on_light(scene)
                        shadowray = Ray(ht.point, normalize(lightp - ht.point))

                        shr = hit_in_scene(scene, shadowray)
                        if !isnothing(shr) && length(shr[1].point - lightp) < kEPS
                            G = abs(dot(lightnormal, shadowray.direction)) * abs(dot(shadowray.direction, ht.normal)) / length(lightp - ht.point)^2
                            result.data[i, j] += light.emit * weight * object.color * area_size(light) * G
                        end

                        prev_nee_contributed = true
                    else
                        prev_nee_contributed = false
                    end

                    russian_roulette = 0.75

                    if count > russian_roulette_max
                        russian_roulette *= 0.5
                    end
                    if count < russian_roulette_min
                        russian_roulette = 1.0
                    elseif rand() < russian_roulette
                        break
                    end

                    weightdelta, ray = nextpath(object.reflection, ray, ht, orientnormal, object.ni)
                    weight *= object.color * weightdelta / russian_roulette
                    hr = hit_in_scene(scene, ray)
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

export Camera, Scene, render

end
