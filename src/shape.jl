module Shapes

using ...Vectors
using ...Images
using ...Rays

struct Sphere
    center::Vec3
    radius::Float64
    color::RGB
    emit::RGB
    reflection::Reflection
end

function sample_on(sphere::Sphere)::Vec3
    phy = 2π * rand()
    z = rand()

    k = sqrt(1 - z^2)

    return sphere.radius * Vec3(k * cos(phy), k * sin(phy), z) + sphere.center
end

function is_light(sphere::Sphere)::Bool
    return sphere.emit.r > 0 || sphere.emit.g > 0 || sphere.emit.b > 0
end

function area_size(sphere::Sphere)::Float64
    return 4π * sphere.radius^2
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

function sample_on(rect::Rectangle)::Vec3
    return rect.vertex + rand() * rect.edge1 + rand() * rect.edge2
end

function is_light(rect::Rectangle)::Bool
    return rect.emit.r > 0 || rect.emit.g > 0 || rect.emit.b > 0
end

function area_size(rect::Rectangle)::Float64
    return length(cross(rect.edge1, rect.edge2))
end

struct Triangle
    vertex::Vec3
    edge1::Vec3
    edge2::Vec3
    color::RGB
    emit::RGB
    reflection::Reflection
end

function hit(triangle::Triangle, ray::Ray)::Union{HitRecord,Nothing}
    pvec = cross(ray.direction, triangle.edge2)
    det = dot(triangle.edge1, pvec)

    if abs(det) < kEPS
        return nothing
    end

    invdet = 1 / det

    tvec = ray.origin - triangle.vertex
    u = dot(tvec, pvec) * invdet
    if u < 0 || u > 1
        return nothing
    end

    qvec = cross(tvec, triangle.edge1)
    v = dot(ray.direction, qvec) * invdet
    if v < 0 || u + v > 1
        return nothing
    end

    t = dot(triangle.edge2, qvec) * invdet

    if t < kEPS
        return nothing
    end

    point = ray.origin + t * ray.direction

    return HitRecord(
        point,
        normalize(cross(triangle.edge1, triangle.edge2)),
        t,
    )
end

struct Mesh
    triangles::Vector{Triangle}
    reflection::Reflection
    color::RGB
    emit::RGB

    function Mesh(triangles::Vector{Triangle})
        return new(triangles, diffuse, RGB(0, 0, 0), RGB(0, 0, 0))
    end

    function Mesh(faces::Vector{Vector{Vec3}})
        triangles = Vector{Triangle}()
        for face in faces
            origin = face[1]
            prev = face[2]
            for current in face[3:end]
                push!(triangles, Triangle(origin, prev - origin, current - origin, RGB(0.5, 0.5, 0.5), RGB(0, 0, 0), diffuse))
                prev = current
            end
        end

        return new(triangles, diffuse, RGB(0, 0, 0), RGB(0, 0, 0))
    end
end

function hit(mesh::Mesh, ray::Ray)::Union{HitRecord,Nothing}
    distance = Inf
    hr = nothing

    for triangle in mesh.triangles
        h = hit(triangle, ray)
        if !isnothing(h) && h.distance < distance
            distance = h.distance
            hr = h
        end
    end

    return hr
end

export Sphere, Box, rotate_y, Rectangle, hit, is_light, sample_on, area_size, Triangle, Mesh

end
