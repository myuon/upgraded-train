include("src/util.jl")
include("src/vector.jl")
include("src/image.jl")
include("src/loader.jl")
include("src/loader_mitsuba.jl")
include("src/ray.jl")
include("src/shape.jl")
include("src/renderer.jl")
include("src/bvh.jl")

using .Vectors
using .Images
using .Loaders: load_obj
using .Renderers
using .Shapes
using .Rays
using .MitsubaLoaders: load_scene
using .PathUtils: change_base_path

const spp = parse(Int, get(ENV, "SPP", "4"))
const enable_NEE = get(ENV, "ENABLE_NEE", "true") == "true"
const enable_TONE_MAP = get(ENV, "ENABLE_TONE_MAP", "true") == "true"
const enable_DEBUG_HIT_NORMAL = get(ENV, "ENABLE_DEBUG_HIT_NORMAL", "false") == "true"
const disable_SHADING_NORMAL = get(ENV, "DISABLE_SHADING_NORMAL", "false") == "true"
const OBJ_FILE = get(ENV, "OBJ_FILE", "")
const MITSU_FILE = get(ENV, "MITSU_FILE", "")

import EzXML

function spheremesh(center::Tuple{Float64,Float64,Float64}, radius::Float64)::Vector{Vector{Vec3}}
    vertices = Vector{Vec3}()
    faces = Vector{Vector{Vec3}}()

    subdivisions = 9

    for i in 0:subdivisions
        for j in 0:subdivisions
            u = i / subdivisions
            v = j / subdivisions

            theta = 2π * u
            phi = π * v

            x = cos(theta) * sin(phi)
            y = sin(theta) * sin(phi)
            z = cos(phi)

            push!(vertices, Vec3(x, y, z))
        end
    end

    vertices = [v * radius + Vec3(center...) for v in vertices]

    for i in 0:(subdivisions-1)
        for j in 0:(subdivisions-1)
            a = i * (subdivisions + 1) + j + 1
            b = i * (subdivisions + 1) + j + 2
            c = (i + 1) * (subdivisions + 1) + j + 1
            d = (i + 1) * (subdivisions + 1) + j + 2

            # ?
            if vertices[a] == vertices[c]
                continue
            end
            if vertices[b] == vertices[d]
                continue
            end

            @assert vertices[a] != vertices[b]
            @assert vertices[a] != vertices[c]
            @assert vertices[b] != vertices[c]
            @assert vertices[b] != vertices[d]
            @assert vertices[c] != vertices[d]

            push!(faces, [vertices[a], vertices[b], vertices[c]])
            push!(faces, [vertices[b], vertices[d], vertices[c]])
        end
    end

    return faces
end

function main()
    if MITSU_FILE != ""
        shapes, bsdfs = load_scene(MITSU_FILE)

        meshes = Mesh[]
        for (_, shape) in shapes
            if shape.type == "object"
                objects, _ = load_obj(change_base_path(MITSU_FILE, shape.objfile))
                object = objects[""]
                bsdf = bsdfs[shape.bsdfid]

                color = RGB(bsdf.reflectance[1], bsdf.reflectance[2], bsdf.reflectance[3])
                emission = RGB(bsdf.k[1], bsdf.k[2], bsdf.k[3])
                ni = 1.0

                if bsdf.type == "diffuse"
                    reflection = diffuse
                elseif bsdf.type == "dielectric"
                    reflection = refractive
                    ni = bsdf.ior
                    color = RGB(1.0, 1.0, 1.0)
                elseif bsdf.type == "roughconductor"
                    reflection = specular
                    color = RGB(1.0, 1.0, 1.0)
                end

                if length(object.normals) > 0 && !disable_SHADING_NORMAL
                    push!(meshes, Mesh(object.faces, object.normals, color, emission, reflection, ni))
                else
                    push!(meshes, Mesh(object.faces, color, emission, reflection, ni))
                end
            elseif shape.type == "rectangle"
                m = shape.matrix
                bsdf = bsdfs[shape.bsdfid]

                color = RGB(1.0, 1.0, 1.0)
                emission = RGB(shape.radiance[1], shape.radiance[2], shape.radiance[3])
                ni = 1.0

                if bsdf.type == "diffuse"
                    reflection = diffuse
                elseif bsdf.type == "dielectric"
                    reflection = refractive
                    ni = bsdf.ior
                elseif bsdf.type == "roughconductor"
                    reflection = specular
                end

                push!(meshes, Mesh(
                    [[
                        Vec3(-m[1] - m[2] + m[4], -m[5] - m[6] + m[8], -m[9] - m[10] + m[12]),
                        Vec3(m[1] - m[2] + m[4], m[5] - m[6] + m[8], m[9] - m[10] + m[12]),
                        Vec3(m[1] + m[2] + m[4], m[5] + m[6] + m[8], m[9] + m[10] + m[12]),
                        Vec3(-m[1] + m[2] + m[4], -m[5] + m[6] + m[8], -m[9] + m[10] + m[12]),
                    ]],
                    color, emission, reflection, ni)
                )
            elseif shape.type == "sphere"
                bsdf = bsdfs[shape.bsdfid]

                color = RGB(1.0, 1.0, 1.0)
                emission = RGB(shape.radiance[1], shape.radiance[2], shape.radiance[3])
                ni = 1.0

                if bsdf.type == "diffuse"
                    reflection = diffuse
                elseif bsdf.type == "dielectric"
                    reflection = refractive
                    ni = bsdf.ior
                elseif bsdf.type == "roughconductor"
                    reflection = specular
                end

                push!(meshes, Mesh(
                    spheremesh(shape.spherecenter, shape.sphereradius),
                    color,
                    emission,
                    reflection,
                    ni,
                ))
            end
        end

        camera = Camera(
            Vec3(16.2155, 4.05167, 0.0114864),
            normalize(Vec3(0.0, 0.999989, -0.00467011)),
            -normalize(Vec3(0.999987, -2.34659e-5, -0.00502464)),
            7,
        )
    elseif OBJ_FILE != ""
        objects, materials = load_obj(OBJ_FILE)

        meshes = Mesh[]
        for (name, object) in objects
            material = materials[name]
            color = RGB(material.Ka[1], material.Ka[2], material.Ka[3])
            ni = 1.0
            if length(material.Ke) == 3
                emission = RGB(material.Ke[1], material.Ke[2], material.Ke[3])
            else
                emission = RGB(0.0, 0.0, 0.0)
            end
            if material.illum == 5
                reflection = specular
                color = RGB(1.0, 1.0, 1.0)
            elseif material.illum == 7
                reflection = refractive
                color = RGB(1.0, 1.0, 1.0)
                ni = material.Ni
            else
                reflection = diffuse
            end

            if length(object.faces) == 0
                continue
            end

            if length(object.normals) > 0 && !disable_SHADING_NORMAL
                push!(meshes, Mesh(object.faces, object.normals, color, emission, reflection, ni))
            else
                push!(meshes, Mesh(object.faces, color, emission, reflection, ni))
            end
        end

        camera = Camera(
            Vec3(0.0, 1.0, 5.0),
            normalize(Vec3(0.0, 1.0, 0.0)),
            normalize(Vec3(0.0, 0.0, -1.0)),
            4,
        )
    end

    scene = Scene(
        camera,
        7.0,
        meshes,
    )

    result = render(scene, (640, 480), spp, enable_NEE, enable_DEBUG_HIT_NORMAL)

    save("output", result, 2.2, enable_TONE_MAP)
end

main()
