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
    objects::Vector{Sphere}
    rectangles::Vector{Rectangle}
    boxes::Vector{Box}
end

function hit_in_scene(scene::Scene, ray::Ray)::Union{Tuple{HitRecord,Union{Sphere,Rectangle,Box}},Nothing}
    distance = Inf
    result = nothing

    for object in scene.objects
        hr = hit(object, ray)
        if !isnothing(hr) && hr.distance < distance
            result = hr, object
            distance = hr.distance
        end
    end
    for rectangle in scene.rectangles
        hr = hit(rectangle, ray)
        if !isnothing(hr) && hr.distance < distance
            result = hr, rectangle
            distance = hr.distance
        end
    end
    for box in scene.boxes
        hr = hit(box, ray)
        if !isnothing(hr) && hr.distance < distance
            result = hr, box
            distance = hr.distance
        end
    end

    return result
end

function sample_on_light(scene::Scene)::Tuple{Union{Sphere,Rectangle},Vec3}
    sample_count = 0
    for object in scene.objects
        if is_light(object)
            sample_count += 1
        end
    end
    for rectangle in scene.rectangles
        if is_light(rectangle)
            sample_count += 1
        end
    end

    light_index = rand(1:sample_count)

    sample_count = 0
    for object in scene.objects
        if is_light(object)
            sample_count += 1
            if sample_count == light_index
                return object, sample_on(object)
            end
        end
    end
    for rectangle in scene.rectangles
        if is_light(rectangle)
            sample_count += 1
            if sample_count == light_index
                return rectangle, sample_on(rectangle)
            end
        end
    end
end

const russian_roulette_min = 5
const russian_roulette_max = 10

function render(scene::Scene, size::Tuple{Int,Int}, spp::Int, enable_NEE::Bool)::Image
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
                while !isnothing(hr)
                    count += 1
                    ht, object = hr
                    orientnormal = dot(ht.normal, ray.direction) < 0 ? ht.normal : -ht.normal

                    if !enable_NEE || !prev_nee_contributed
                        result.data[i, j] += object.emit * weight
                    end
                    if enable_NEE && object.reflection == diffuse
                        light, lightp = sample_on_light(scene)
                        shadowray = Ray(ht.point, normalize(lightp - ht.point))

                        shr = hit_in_scene(scene, shadowray)
                        if !isnothing(shr) && length(shr[1].point - lightp) < kEPS
                            G = abs(dot(normalize(cross(shr[2].edge1, shr[2].edge2)), shadowray.direction)) * abs(dot(shadowray.direction, ht.normal)) / length(lightp - ht.point)^2
                            result.data[i, j] += light.emit * weight * object.color * area_size(light) * G
                        end

                        prev_nee_contributed = true
                    else
                        prev_nee_contributed = false
                    end

                    russian_roulette = max(object.color.r, object.color.g, object.color.b)

                    if count > russian_roulette_max
                        russian_roulette *= 0.5
                    end
                    if count < russian_roulette_min
                        russian_roulette = 1.0
                    elseif rand() < russian_roulette || russian_roulette < kEPS
                        break
                    end

                    weightdelta, ray = nextpath(object.reflection, ht, orientnormal)
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
