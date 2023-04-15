module MitsubaLoaders

using EzXML

struct Shape
    id::String
    objfile::String
    bsdfid::String
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
        if element.name == "shape" && element["type"] == "obj"
            name = element["id"]
            shapes[name] = Shape(name, find(element, "string")["value"], find(element, "ref")["id"])
        end

        if element.name == "bsdf"
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

