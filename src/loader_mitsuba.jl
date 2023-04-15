module MitsubaLoaders

using EzXML

struct Shape
    id::String
    type::String
    objfile::String
    bsdfid::String
    radiance::Tuple{Float64,Float64,Float64}
    matrix::Array{Float64}
    spherecenter::Tuple{Float64,Float64,Float64}
    sphereradius::Float64
end

struct Bsdf
    id::String
    type::String
    reflectance::Tuple{Float64,Float64,Float64}
    ior::Float64
    specular_reflectance::Tuple{Float64,Float64,Float64}
    k::Tuple{Float64,Float64,Float64}
end

function load_scene(filename::String)
    file_content = read(filename, String)
    scene = parsexml(file_content)

    shapes = Dict{String,Shape}()
    bsdfs = Dict{String,Bsdf}()

    for element in eachelement(scene.root)
        if element.name == "shape"

            emitter = find(element, "emitter")
            if !isnothing(emitter)
                radiance_str = findbyname(emitter, "rgb", "radiance")
                radiance_array = [parse(Float64, x) for x in split(radiance_str["value"], ",")]
                radiance = (radiance_array[1], radiance_array[2], radiance_array[3])
            else
                radiance = (0.0, 0.0, 0.0)
            end

            if element["type"] == "obj"
                name = element["id"]
                shapes[name] = Shape(name, "object", find(element, "string")["value"], find(element, "ref")["id"], (0.0, 0.0, 0.0), [], (0.0, 0.0, 0.0), 0.0)
            elseif element["type"] == "rectangle"
                name = element["id"]

                matrix_str = find(findbyname(element, "transform", "to_world"), "matrix")["value"]
                matrix = [parse(Float64, x) for x in split(matrix_str, " ")]

                shapes[name] = Shape(name, "rectangle", "", find(element, "ref")["id"], radiance, matrix, (0.0, 0.0, 0.0), 0.0)
            elseif element["type"] == "sphere"
                name = element["id"]

                centerx = parse(Float64, findbyname(element, "point", "center")["x"])
                centery = parse(Float64, findbyname(element, "point", "center")["y"])
                centerz = parse(Float64, findbyname(element, "point", "center")["z"])

                radius = parse(Float64, findbyname(element, "float", "radius")["value"])

                shapes[name] = Shape(name, "sphere", "", find(element, "ref")["id"], radiance, [], (centerx, centery, centerz), radius)
            end
        elseif element.name == "bsdf"
            b = bsdf(element, "")
            bsdfs[b.id] = b
        end
    end

    return shapes, bsdfs
end

function find(node::EzXML.Node, tag::String)
    for element in eachelement(node)
        if element.name == tag
            return element
        end
    end

    return nothing
end

function findbyname(node::EzXML.Node, tag::String, name::String)
    for element in eachelement(node)
        if element.name == tag && element["name"] == name
            return element
        end
    end

    return nothing
end

function bsdf(node::EzXML.Node, id::String)::Bsdf
    child = find(node, "bsdf")
    if !isnothing(child)
        return bsdf(child, haskey(node, "id") ? node["id"] : id)
    end

    if node["type"] == "diffuse"
        reflectance_str = findbyname(node, "rgb", "reflectance")["value"]
        reflectance = [parse(Float64, x) for x in split(reflectance_str, ",")]

        id = haskey(node, "id") ? node["id"] : id

        return Bsdf(id, "diffuse", (reflectance[1], reflectance[2], reflectance[3]), 0, (0, 0, 0), (0.0, 0.0, 0.0))
    elseif node["type"] == "roughconductor"
        specular_reflectance_str = findbyname(node, "rgb", "specular_reflectance")["value"]
        specular_reflectance = [parse(Float64, x) for x in split(specular_reflectance_str, ",")]

        k_str = findbyname(node, "float", "alpha")["value"]
        k = [parse(Float64, x) for x in split(k_str, ",")]

        id = haskey(node, "id") ? node["id"] : id

        return Bsdf(id, "roughconductor", (0, 0, 0), 0, (specular_reflectance[1], specular_reflectance[2], specular_reflectance[3]), (k[1], k[1], k[1]))
    elseif node["type"] == "dielectric"
        type = "dielectric"
        ior = parse(Float64, findbyname(node, "float", "int_ior")["value"])

        id = haskey(node, "id") ? node["id"] : id

        return Bsdf(id, type, (0, 0, 0), ior, (0, 0, 0), (0.0, 0.0, 0.0))
    end
end

export load_scene

end

