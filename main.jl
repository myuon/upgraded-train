include("src/vector.jl")
include("src/image.jl")
include("src/loader.jl")
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

const spp = parse(Int, get(ENV, "SPP", "4"))
const enable_NEE = get(ENV, "ENABLE_NEE", "true") == "true"
const enable_TONE_MAP = get(ENV, "ENABLE_TONE_MAP", "true") == "true"
const enable_DEBUG_HIT_NORMAL = get(ENV, "ENABLE_DEBUG_HIT_NORMAL", "false") == "true"
const disable_SHADING_NORMAL = get(ENV, "DISABLE_SHADING_NORMAL", "false") == "true"
const OBJ_FILE = get(ENV, "OBJ_FILE", "assets/test.obj")

function main()
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

    scene = Scene(
        Camera(
            Vec3(0.0, 1.0, 5.0),
            normalize(Vec3(0.0, 1.0, 0.0)),
            normalize(Vec3(0.0, 0.0, -1.0)),
            5,
        ),
        4,
        meshes,
    )

    result = render(scene, (640, 480), spp, enable_NEE, enable_DEBUG_HIT_NORMAL)

    save("output", result, 2.2, enable_TONE_MAP)
end

main()
