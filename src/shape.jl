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

function sample_on(rect::Rectangle)::Tuple{Vec3,UnitVec3}
    return rect.vertex + rand() * rect.edge1 + rand() * rect.edge2, normalize(cross(rect.edge1, rect.edge2))
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
end

function vertices_triangle(triangle::Triangle)::Tuple{Vec3,Vec3,Vec3}
    return triangle.vertex, triangle.vertex + triangle.edge1, triangle.vertex + triangle.edge2
end

function det(a::Vec3, b::Vec3, c::Vec3)::Float64
    return a.data[1] * b.data[2] * c.data[3] +
           a.data[2] * b.data[3] * c.data[1] +
           a.data[3] * b.data[1] * c.data[2] -
           a.data[3] * b.data[2] * c.data[1] -
           a.data[2] * b.data[1] * c.data[3] -
           a.data[1] * b.data[3] * c.data[2]
end

function hit(triangle::Triangle, ray::Ray)::Union{HitRecord,Nothing}
    d = det(triangle.edge1, triangle.edge2, -as_vec3(ray.direction))

    s1 = det(ray.origin - triangle.vertex, triangle.edge2, -as_vec3(ray.direction)) / d
    s2 = det(triangle.edge1, ray.origin - triangle.vertex, -as_vec3(ray.direction)) / d
    t = det(triangle.edge1, triangle.edge2, ray.origin - triangle.vertex) / d

    if s1 < kEPS || s2 < kEPS || s1 + s2 > 1.0
        return nothing
    end
    if abs(t) < kEPS
        return nothing
    end

    return HitRecord(
        ray.origin + t * ray.direction,
        normalize(cross(triangle.edge1, triangle.edge2)),
        t,
    )
end

struct NormalTriangle
    vertex::Vec3
    vn0::UnitVec3
    edge1::Vec3
    vn1::UnitVec3
    edge2::Vec3
    vn2::UnitVec3
end

function vertices_triangle(triangle::NormalTriangle)::Tuple{Vec3,Vec3,Vec3}
    return triangle.vertex, triangle.vertex + triangle.edge1, triangle.vertex + triangle.edge2
end

function center(triangle::Triangle)::Vec3
    return triangle.vertex + 0.5 * triangle.edge1 + 0.5 * triangle.edge2
end

function hit(triangle::NormalTriangle, ray::Ray)::Union{HitRecord,Nothing}
    d = det(triangle.edge1, triangle.edge2, -as_vec3(ray.direction))

    s1 = det(ray.origin - triangle.vertex, triangle.edge2, -as_vec3(ray.direction)) / d
    s2 = det(triangle.edge1, ray.origin - triangle.vertex, -as_vec3(ray.direction)) / d
    t = det(triangle.edge1, triangle.edge2, ray.origin - triangle.vertex) / d

    if s1 < kEPS || s2 < kEPS || s1 + s2 > 1.0
        return nothing
    end
    if abs(t) < kEPS
        return nothing
    end

    return HitRecord(
        ray.origin + t * ray.direction,
        normalize(s1 * triangle.vn1 + s2 * triangle.vn2 + (1 - s1 - s2) * triangle.vn0),
        t,
    )
end

struct AABB
    minv::Vec3
    maxv::Vec3

    function AABB(min::Vec3, max::Vec3)
        return new(min, max)
    end

    function AABB(triangles::Vector{Triangle})
        minv = triangles[1].vertex
        maxv = triangles[1].vertex
        for triangle in triangles
            for v in vertices_triangle(triangle)
                minv = min(minv, v)
                maxv = max(maxv, v)
            end
        end

        return new(minv, maxv)
    end

    function AABB(triangles::Vector{NormalTriangle})
        minv = triangles[1].vertex
        maxv = triangles[1].vertex
        for triangle in triangles
            for v in vertices_triangle(triangle)
                minv = min(minv, v)
                maxv = max(maxv, v)
            end
        end

        return new(minv, maxv)
    end
end

function hit_if(aabb::AABB, ray::Ray)::Bool
    tmin = (aabb.minv.data[1] - ray.origin.data[1]) / ray.direction.data[1]
    tmax = (aabb.maxv.data[1] - ray.origin.data[1]) / ray.direction.data[1]

    if tmin > tmax
        tmin, tmax = tmax, tmin
    end

    tymin = (aabb.minv.data[2] - ray.origin.data[2]) / ray.direction.data[2]
    tymax = (aabb.maxv.data[2] - ray.origin.data[2]) / ray.direction.data[2]

    if tymin > tymax
        tymin, tymax = tymax, tymin
    end

    if (tmin > tymax) || (tymin > tmax)
        return false
    end

    if tymin > tmin
        tmin = tymin
    end

    if tymax < tmax
        tmax = tymax
    end

    tzmin = (aabb.minv.data[3] - ray.origin.data[3]) / ray.direction.data[3]
    tzmax = (aabb.maxv.data[3] - ray.origin.data[3]) / ray.direction.data[3]

    if tzmin > tzmax
        tzmin, tzmax = tzmax, tzmin
    end

    if (tmin > tzmax) || (tzmin > tmax)
        return false
    end

    return true
end

function merge(a::AABB, b::AABB)::AABB
    return AABB(
        Vec3(min(a.min.data[1], b.min.data[1]), min(a.min.data[2], b.min.data[2]), min(a.min.data[3], b.min.data[3])),
        Vec3(max(a.max.data[1], b.max.data[1]), max(a.max.data[2], b.max.data[2]), max(a.max.data[3], b.max.data[3])),
    )
end

struct Mesh
    hasnormal::Bool
    triangles::Vector{Triangle}
    ntriangles::Vector{NormalTriangle}
    bbox::AABB
    color::RGB
    emit::RGB
    reflection::Reflection

    function Mesh(faces::Vector{Vector{Vec3}}, color::RGB, emission::RGB, reflection::Reflection)
        triangles = Vector{Triangle}()
        for face in faces
            origin = face[1]
            prev = face[2]
            for current in face[3:end]
                push!(triangles, Triangle(origin, prev - origin, current - origin))
                prev = current
            end
        end

        return new(false, triangles, [], normals, AABB(triangles), color, emission, reflection)
    end

    function Mesh(faces::Vector{Vector{Vec3}}, normals::Vector{Vector{Vec3}}, color::RGB, emission::RGB, reflection::Reflection)
        triangles = Vector{NormalTriangle}()
        for i in 1:length(faces)
            face = faces[i]
            ns = normals[i]
            origin = face[1]
            on = ns[1]
            prev = face[2]
            prevn = ns[2]
            for j in 3:length(face)
                current = face[j]
                currentn = ns[j]
                push!(
                    triangles,
                    NormalTriangle(
                        origin,
                        normalize(on),
                        prev - origin,
                        normalize(prevn),
                        current - origin,
                        normalize(currentn),
                    )
                )
                prev = current
            end
        end

        return new(true, [], triangles, AABB(triangles), color, emission, reflection)
    end
end

function hit(mesh::Mesh, ray::Ray)::Union{HitRecord,Nothing}
    if !hit_if(mesh.bbox, ray)
        return nothing
    end

    distance = Inf
    hr = nothing

    if mesh.hasnormal
        for triangle in mesh.ntriangles
            h = hit(triangle, ray)
            if !isnothing(h) && h.distance < distance
                distance = h.distance
                hr = h
            end
        end
    else
        for triangle in mesh.triangles
            h = hit(triangle, ray)
            if !isnothing(h) && h.distance < distance
                distance = h.distance
                hr = h
            end
        end
    end

    return hr
end

function is_light(mesh::Mesh)::Bool
    return mesh.emit.r > 0 || mesh.emit.g > 0 || mesh.emit.b > 0
end

function sample_on(mesh::Mesh)::Tuple{Vec3,UnitVec3}
    if mesh.hasnormal
        triangle = mesh.ntriangles[rand(1:length(mesh.ntriangles))]
    else
        triangle = mesh.triangles[rand(1:length(mesh.triangles))]
    end
    return triangle.vertex + rand() * triangle.edge1 + rand() * triangle.edge2, normalize(cross(triangle.edge1, triangle.edge2))
end

function area_size(mesh::Mesh)::Float64
    area = 0.0
    if mesh.hasnormal
        for triangle in mesh.ntriangles
            area += length(cross(triangle.edge1, triangle.edge2)) / 2.0
        end
    else
        for triangle in mesh.triangles
            area += length(cross(triangle.edge1, triangle.edge2)) / 2.0
        end
    end

    return area
end

export Sphere, Box, rotate_y, Rectangle, hit, is_light, sample_on, area_size, Triangle, Mesh, vertices_triangle, center, NormalTriangle, NormalMesh

end
