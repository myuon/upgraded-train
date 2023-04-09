module Rays

using ...Vectors

const kEPS = 1e-6

struct Ray
    origin::Vec3
    direction::UnitVec3
end

struct HitRecord
    point::Vec3
    normal::UnitVec3
    distance::Float64
end

@enum Reflection diffuse specular refractive

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

function nextpath(reflection::Reflection, ht::HitRecord, orientnormal::UnitVec3)::Tuple{Float64,Ray}
    if reflection == diffuse
        1.0, Ray(ht.point, sample_lambertian_cosine_pdf(orientnormal))
    elseif reflection == specular
        1.0, Ray(ht.point, normalize(as_vec3(ray.direction) - ht.normal * 2.0 * dot(ht.normal, ray.direction)))
    elseif reflection == refractive
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
                Re / prob, reflectionray
            else
                Tr / (1 - prob), refractionray
            end
        end
    else
        error("Invalid reflection type: $(reflection)")
    end
end

export Ray, HitRecord, kEPS, Reflection, diffuse, specular, refractive, nextpath

end
