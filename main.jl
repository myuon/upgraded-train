include("image.jl")
include("vectors.jl")

kEPS = 1e-6

using .Vectors
using .Images

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

struct Scene
    camera::Camera
    screensize::Int
    objects::Vector{Sphere}
end

function hit_in_scene(scene::Scene, ray::Ray)::Union{Tuple{HitRecord,Sphere},Nothing}
    distance = Inf
    result = nothing

    for object in scene.objects
        hr = hit(object, ray)
        if !isnothing(hr) && hr.distance < distance
            result = hr, object
            distance = hr.distance
        end
    end

    return result
end

function sample_on_light(scene::Scene)::Tuple{Sphere,Vec3}
    sample_count = 0
    for object in scene.objects
        if is_light(object)
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
end

const spp = parse(Int, get(ENV, "SPP", "4"))
const enable_NEE = get(ENV, "ENABLE_NEE", "true") == "true"

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
                        if !isnothing(shr) && shr[2].center == light.center
                            result.data[i, j] += light.emit * weight * object.color * 4 * dot(shadowray.direction, orientnormal)
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

function main()
    scene = Scene(
        Camera(Vec3(50.0, 52.0, 220.0), normalize(Vec3(0.0, 1.0, 0.0)), normalize(Vec3(0.0, -0.04, -1.0)), 30),
        30.0,
        [
            Sphere(Vec3(1e5 + 1, 40.8, 81.6), 1e5, RGB(0.75, 0.25, 0.25), RGB(0.0, 0.0, 0.0), diffuse),
            Sphere(Vec3(-1e5 + 99, 40.8, 81.6), 1e5, RGB(0.25, 0.25, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
            Sphere(Vec3(50.0, 40.8, 1e5), 1e5, RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
            Sphere(Vec3(50.0, 40.8, -1e5 + 250), 1e5, RGB(0.0, 0.0, 0.0), RGB(0.0, 0.0, 0.0), diffuse),
            Sphere(Vec3(50.0, 1e5, 81.6), 1e5, RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
            Sphere(Vec3(50.0, -1e5 + 81.6, 81.6), 1e5, RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
            Sphere(Vec3(65.0, 20.0, 20.0), 20.0, RGB(0.25, 0.75, 0.25), RGB(0.0, 0.0, 0.0), diffuse),
            Sphere(Vec3(27.0, 16.5, 47.0), 16.5, RGB(0.99, 0.99, 0.99), RGB(0.0, 0.0, 0.0), specular),
            Sphere(Vec3(77.0, 16.5, 78.0), 16.5, RGB(0.99, 0.99, 0.99), RGB(0.0, 0.0, 0.0), refractive),
            Sphere(Vec3(50.0, 70.0, 81.6), 5.0, RGB(0.0, 0.0, 0.0), RGB(0.5, 0.5, 0.5), diffuse),
        ],
    )

    result = render(scene, (640, 480))

    save("output", result, 2.2)
end

main()
