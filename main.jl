include("src/vector.jl")
include("src/image.jl")
include("src/loader.jl")
include("src/ray.jl")
include("src/shape.jl")
include("src/renderer.jl")

using .Vectors
using .Images
using .Loaders: load_obj
using .Renderers
using .Shapes
using .Rays

const spp = parse(Int, get(ENV, "SPP", "4"))
const enable_NEE = get(ENV, "ENABLE_NEE", "true") == "true"
const enable_TONE_MAP = get(ENV, "ENABLE_TONE_MAP", "true") == "true"
const OBJ_FILE = get(ENV, "OBJ_FILE", "assets/test.obj")

function main()
    objects, materials = load_obj(OBJ_FILE)

    meshes = Mesh[]
    for (name, object) in objects
        material = materials[name]
        color = RGB(material.Ka[1], material.Ka[2], material.Ka[3])
        push!(meshes, Mesh(object.faces, color))
    end

    scene = Scene(
        Camera(
            Vec3(0.0, 1.0, 5.0),
            normalize(Vec3(0.0, 1.0, 0.0)),
            normalize(Vec3(0.0, 0.0, -1.0)),
            5,
        ),
        4,
        [],
        [
            Rectangle(Vec3(40.0, 99.0, 50.0), Vec3(0.0, 0.0, 15.0), Vec3(15.0, 0.0, 0.0), RGB(1.0, 1.0, 1.0), 36.0 * RGB(1.0, 1.0, 1.0), diffuse),
        ],
        [],
        meshes,
    )

    result = render(scene, (640, 480), spp, enable_NEE)

    save("output", result, 2.2, enable_TONE_MAP)
end

main()
