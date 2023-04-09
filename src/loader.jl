module Loaders

import ...Vectors

struct Face
    indices::Vector{Int}
end

mutable struct Object
    name::String
    material::String
    vertices::Vector{Vectors.Vec3}
    faces::Vector{Face}
end

function load_obj(filename::String)
    file_content = read(filename, String)
    lines = split(file_content, '\n')
    objects = Dict{String,Object}()
    materials = nothing

    object = Object(".", "", [], [])

    for line in lines
        tokens = split(line)
        if isempty(tokens)
            continue
        end

        keyword = tokens[1]

        if keyword == "mtllib"
            materials = load_mtl_file(change_base_path(filename, String(tokens[2])))
        elseif keyword == "g"
            objects[object.name] = object
            object = Object(String(tokens[2]), "", [], [])
        elseif keyword == "v"
            push!(object.vertices, Vectors.Vec3(parse(Float64, tokens[2]), parse(Float64, tokens[3]), parse(Float64, tokens[4])))
        elseif keyword == "usemtl"
            object.material = String(tokens[2])
        elseif keyword == "f"
            face_indices = [parse(Int, x) for x in tokens[2:end]]
            push!(object.faces, Face(face_indices))
        end
    end

    objects[object.name] = object

    return objects, materials
end

function change_base_path(filepath::String, new_base::String)
    dir, _ = splitdir(filepath)
    return joinpath(dir, new_base)
end

mutable struct Material
    name::String
    Ns::Float64
    Ni::Float64
    illum::Int
    Ka::Vector{Float64}
    Kd::Vector{Float64}
    Ks::Vector{Float64}
    Ke::Vector{Float64}
end

function parse_mtl_file(mtl_string::String)
    materials = Dict{String,Material}()
    lines = split(mtl_string, "\r\n")
    material = nothing

    for line in lines
        tokens = split(line, ' ')

        if tokens[1] == "newmtl"
            if !isnothing(material)
                materials[material.name] = material
            end

            material = Material(String(tokens[2]), 0, 0, 0, [], [], [], [])
        elseif tokens[1] == "Ns"
            material.Ns = parse(Float64, tokens[2])
        elseif tokens[1] == "Ni"
            material.Ni = parse(Float64, tokens[2])
        elseif tokens[1] == "illum"
            material.illum = parse(Int, tokens[2])
        elseif tokens[1] in ["Ka", "Kd", "Ks", "Ke"]
            color = [parse(Float64, token) for token in tokens[2:end]]
            if tokens[1] == "Ka"
                material.Ka = color
            elseif tokens[1] == "Kd"
                material.Kd = color
            elseif tokens[1] == "Ks"
                material.Ks = color
            elseif tokens[1] == "Ke"
                material.Ke = color
            end
        end
    end

    materials[material.name] = material

    return materials
end

function load_mtl_file(filename::String)
    file_content = read(filename, String)
    return parse_mtl_file(file_content)
end

export parse_obj, load_obj

end
