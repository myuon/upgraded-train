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

function sample_lambertian_cosine_pdf(normal::UnitVec3)::UnitVec3
    w = normal
    if abs(w.data[1]) > kEPS
        u = normalize(cross(Vec3(0.0, 1.0, 0.0), w))
    else
        u = normalize(cross(Vec3(1.0, 0.0, 0.0), w))
    end

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

function is_same_shape(a::Union{Sphere,Rectangle,Box}, b::Union{Sphere,Rectangle,Box})::Bool
    if a isa Sphere && b isa Sphere
        return a.center == b.center && a.radius == b.radius
    elseif a isa Rectangle && b isa Rectangle
        return a.vertex == b.vertex && a.edge1 == b.edge1 && a.edge2 == b.edge2
    elseif a isa Box && b isa Box
        return a.vertex == b.vertex && a.edge1 == b.edge1 && a.edge2 == b.edge2 && a.edge3 == b.edge3
    else
        return false
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
                        if !isnothing(shr) && is_same_shape(shr[2], light)
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

                    if object.reflection == diffuse
                        weight *= object.color / russian_roulette
                        ray = Ray(ht.point, sample_lambertian_cosine_pdf(orientnormal))
                    elseif object.reflection == specular
                        weight *= object.color / russian_roulette
                        ray = Ray(ht.point, normalize(as_vec3(ray.direction) - ht.normal * 2.0 * dot(ht.normal, ray.direction)))
                    elseif object.reflection == refractive
                        reflectionray = Ray(ht.point, normalize(as_vec3(ray.direction) - ht.normal * 2.0 * dot(ht.normal, ray.direction)))
                        into = dot(ht.normal, orientnormal) > 0

                        nc = 1.0
                        nt = 1.5
                        nnt = into ? nc / nt : nt / nc
                        ddn = dot(ray.direction, orientnormal)
                        cos2t = 1.0 - nnt^2 * (1.0 - ddn^2)

                        if cos2t < 0
                            weight *= object.color / russian_roulette
                            ray = reflectionray
                        else
                            refractionray = Ray(ht.point, normalize(as_vec3(ray.direction) * nnt - ht.normal * (into ? 1.0 : -1.0) * (ddn * nnt + sqrt(cos2t))))

                            a = nt - nc
                            b = nt + nc
                            R0 = a^2 / b^2

                            c = 1.0 - (into ? -ddn : dot(refractionray.direction, -orientnormal))

                            Re = R0 + (1.0 - R0) * c^5
                            Tr = (1.0 - Re) * (into ? nc / nt : nt / nc)^2

                            prob = 0.25 + 0.5 * Re
                            if rand() < prob
                                ray = reflectionray
                                weight *= object.color * Re / russian_roulette / prob
                            else
                                ray = refractionray
                                weight *= object.color * Tr / russian_roulette / (1 - prob)
                            end
                        end
                    else
                        break
                    end

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
