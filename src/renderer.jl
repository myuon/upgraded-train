include("image.jl")
include("vectors.jl")
include("loader.jl")

kEPS = 1e-6

using .Vectors
using .Images
using .Loaders

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

@enum Reflection diffuse specular refractive

struct Sphere
    center::Vec3
    radius::Float64
    color::RGB
    emit::RGB
    reflection::Reflection
end

function sample_on_sphere(sphere::Sphere)::Vec3
    phy = 2π * rand()
    z = rand()

    k = sqrt(1 - z^2)

    return sphere.radius * Vec3(k * cos(phy), k * sin(phy), z) + sphere.center
end

function is_light(sphere::Sphere)::Bool
    return sphere.emit.r > 0 || sphere.emit.g > 0 || sphere.emit.b > 0
end

struct HitRecord
    point::Vec3
    normal::UnitVec3
    distance::Float64
end

function hit(sphere::Sphere, ray::Ray)::Union{HitRecord,Nothing}
    po = sphere.center - ray.origin
    b = dot(po, ray.direction)
    discriminant = b^2 - dot(po, po) + sphere.radius^2

    if discriminant < 0
        return nothing
    end

    t1 = b - sqrt(discriminant)
    t2 = b + sqrt(discriminant)
    if t1 < kEPS && t2 < kEPS
        return nothing
    end

    if t1 > kEPS
        distance = t1
    else
        distance = t2
    end

    point = ray.origin + distance * ray.direction

    return HitRecord(
        point,
        normalize(point - sphere.center),
        distance,
    )
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

struct Rectangle
    vertex::Vec3
    edge1::Vec3
    edge2::Vec3
    color::RGB
    emit::RGB
    reflection::Reflection
end

function hit(rect::Rectangle, ray::Ray)::Union{HitRecord,Nothing}
    pvec = cross(ray.direction, rect.edge2)
    det = dot(rect.edge1, pvec)

    if abs(det) < kEPS
        return nothing
    end

    invdet = 1 / det

    tvec = ray.origin - rect.vertex
    u = dot(tvec, pvec) * invdet
    if u < 0 || u > 1
        return nothing
    end

    qvec = cross(tvec, rect.edge1)
    v = dot(ray.direction, qvec) * invdet
    if v < 0 || v > 1
        return nothing
    end

    t = dot(rect.edge2, qvec) * invdet

    if t < kEPS
        return nothing
    end

    point = ray.origin + t * ray.direction

    return HitRecord(
        point,
        normalize(cross(rect.edge1, rect.edge2)),
        t,
    )
end

function sample_on_rectangle(rect::Rectangle)::Vec3
    return rect.vertex + rand() * rect.edge1 + rand() * rect.edge2
end

function is_light(rect::Rectangle)::Bool
    return rect.emit.r > 0 || rect.emit.g > 0 || rect.emit.b > 0
end

struct Box
    vertex::Vec3
    edge1::Vec3
    edge2::Vec3
    edge3::Vec3
    color::RGB
    emit::RGB
    reflection::Reflection
end

function hit(box::Box, ray::Ray)::Union{HitRecord,Nothing}
    distance = Inf
    hr = nothing

    h = hit(Rectangle(box.vertex, box.edge1, box.edge2, box.color, box.emit, box.reflection), ray)
    if !isnothing(h) && h.distance < distance
        distance = h.distance
        hr = h
    end

    h = hit(Rectangle(box.vertex, box.edge1, box.edge3, box.color, box.emit, box.reflection), ray)
    if !isnothing(h) && h.distance < distance
        distance = h.distance
        hr = h
    end

    h = hit(Rectangle(box.vertex, box.edge2, box.edge3, box.color, box.emit, box.reflection), ray)
    if !isnothing(h) && h.distance < distance
        distance = h.distance
        hr = h
    end

    h = hit(Rectangle(box.vertex + box.edge1, box.edge2, box.edge3, box.color, box.emit, box.reflection), ray)
    if !isnothing(h) && h.distance < distance
        distance = h.distance
        hr = h
    end

    h = hit(Rectangle(box.vertex + box.edge2, box.edge1, box.edge3, box.color, box.emit, box.reflection), ray)
    if !isnothing(h) && h.distance < distance
        distance = h.distance
        hr = h
    end

    h = hit(Rectangle(box.vertex + box.edge3, box.edge1, box.edge2, box.color, box.emit, box.reflection), ray)
    if !isnothing(h) && h.distance < distance
        distance = h.distance
        hr = h
    end

    return hr
end

rotate_y(v::Vec3, angle::Float64)::Vec3 = Vec3(
    cos(angle) * v.data[1] + sin(angle) * v.data[3],
    v.data[2],
    -sin(angle) * v.data[1] + cos(angle) * v.data[3],
)

function rotate_y(b::Box, angle::Float64)::Box
    return Box(
        b.vertex,
        rotate_y(b.edge1, angle),
        rotate_y(b.edge2, angle),
        rotate_y(b.edge3, angle),
        b.color,
        b.emit,
        b.reflection,
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
                return object, sample_on_sphere(object)
            end
        end
    end
    for rectangle in scene.rectangles
        if is_light(rectangle)
            sample_count += 1
            if sample_count == light_index
                return rectangle, sample_on_rectangle(rectangle)
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

const spp = parse(Int, get(ENV, "SPP", "4"))
const enable_NEE = get(ENV, "ENABLE_NEE", "true") == "true"
const enable_TONE_MAP = get(ENV, "ENABLE_TONE_MAP", "true") == "true"

const russian_roulette_min = 5
const russian_roulette_max = 10

function render(scene::Scene, size::Tuple{Int,Int})::Image
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
                            G = abs(dot(normalize(cross(shr[2].edge1, shr[2].edge2)), normalize(lightp - ht.point))) * abs(dot(normalize(lightp - ht.point), ht.normal)) / Vectors.length(lightp - ht.point)^2
                            result.data[i, j] += light.emit * weight * object.color * Vectors.length(light.edge1) * Vectors.length(light.edge2) * G
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
                                weight *= object.color * Re / (russian_roulette * prob)
                            else
                                ray = refractionray
                                weight *= object.color * Tr / (russian_roulette * (1 - prob))
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

