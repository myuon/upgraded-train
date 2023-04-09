module Loaders

import ...Vectors

struct Material
    name::String
end

struct Face
    indices::Vector{Int}
    material::Material
end

struct Object
    name::String
    vertices::Vector{Vectors.Vec3}
    faces::Vector{Face}
end

function parse_obj(file_content::String)
    lines = split(file_content, '\n')
    objects = Dict{String,Object}()
    materials = Dict{String,Material}()

    current_material = nothing
    current_object_name = ""
    vertices = Vectors.Vec3[]
    faces = Face[]

    for line in lines
        tokens = split(line)
        if isempty(tokens)
            continue
        end

        keyword = tokens[1]

        if keyword == "mtllib"
            # Do nothing, as we are not parsing material files in this example
        elseif keyword == "g"
            if !isempty(current_object_name)
                objects[current_object_name] = Object(current_object_name, vertices, faces)
                vertices = Vectors.Vec3[]
                faces = Face[]
            end
            current_object_name = tokens[2]
        elseif keyword == "v"
            push!(vertices, Vectors.Vec3(parse(Float64, tokens[2]), parse(Float64, tokens[3]), parse(Float64, tokens[4])))
        elseif keyword == "usemtl"
            current_material_name = tokens[2]
            current_material = get(materials, current_material_name, Material(current_material_name))
            materials[current_material_name] = current_material
        elseif keyword == "f"
            face_indices = [parse(Int, x) for x in tokens[2:end]]
            push!(faces, Face(face_indices, current_material))
        end
    end

    if !isempty(current_object_name)
        objects[current_object_name] = Object(current_object_name, vertices, faces)
    end

    return objects
end

function load_obj(filename::String)
    file_content = read(filename, String)
    return parse_obj(file_content)
end

export parse_obj, load_obj

end
