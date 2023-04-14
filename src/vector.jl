module Vectors

import Base: +
import Base: -
import Base: *
import Base: length
import Base: min
import Base: max

struct Vec3
    data::Tuple{Float64,Float64,Float64}

    function Vec3(vec::Tuple{Float64,Float64,Float64})
        new(vec)
    end

    function Vec3(x::Float64, y::Float64, z::Float64)
        new((x, y, z))
    end
end

as_vector(v::Vec3)::Tuple{Float64,Float64,Float64} = v.data

x(v::Vec3)::Float64 = v.data[1]

y(v::Vec3)::Float64 = v.data[2]

z(v::Vec3)::Float64 = v.data[3]

length(v::Vec3)::Float64 = sqrt(sum(v.data .^ 2))

normalize(v::Vec3)::UnitVec3 = UnitVec3(Vec3(v.data ./ length(v)))

dot(v1::Vec3, v2::Vec3)::Float64 = sum(v1.data .* v2.data)

cross(v1::Vec3, v2::Vec3)::Vec3 = Vec3(
    v1.data[2] * v2.data[3] - v1.data[3] * v2.data[2],
    v1.data[3] * v2.data[1] - v1.data[1] * v2.data[3],
    v1.data[1] * v2.data[2] - v1.data[2] * v2.data[1],
)

+(v1::Vec3, v2::Vec3)::Vec3 = Vec3(v1.data .+ v2.data)

-(v1::Vec3, v2::Vec3)::Vec3 = Vec3(v1.data .- v2.data)

*(v::Vec3, s::Float64)::Vec3 = Vec3(s .* v.data)

*(s::Float64, v::Vec3)::Vec3 = Vec3(s .* v.data)

-(v::Vec3) = Vec3(-v.data[1], -v.data[2], -v.data[3])

min(v1::Vec3, v2::Vec3)::Vec3 = Vec3(min.(v1.data, v2.data))

max(v1::Vec3, v2::Vec3)::Vec3 = Vec3(max.(v1.data, v2.data))

struct UnitVec3
    data::Tuple{Float64,Float64,Float64}

    function UnitVec3(x::Float64, y::Float64, z::Float64)
        @assert x^2 + y^2 + z^2 ≈ 1

        new((x, y, z))
    end

    function UnitVec3(vec::Vec3)
        @assert length(vec) ≈ 1

        new(vec.data)
    end
end

as_vec3(v::UnitVec3)::Vec3 = Vec3(v.data)

x(v::UnitVec3)::Float64 = v.data[1]

y(v::UnitVec3)::Float64 = v.data[2]

z(v::UnitVec3)::Float64 = v.data[3]

normalize(v::UnitVec3)::UnitVec3 = v

dot(v1::UnitVec3, v2::UnitVec3)::Float64 = sum(v1.data .* v2.data)

dot(v1::UnitVec3, v2::Vec3)::Float64 = sum(v1.data .* v2.data)

dot(v1::Vec3, v2::UnitVec3)::Float64 = sum(v1.data .* v2.data)

cross(v1::UnitVec3, v2::UnitVec3)::UnitVec3 = UnitVec3(
    v1.data[2] * v2.data[3] - v1.data[3] * v2.data[2],
    v1.data[3] * v2.data[1] - v1.data[1] * v2.data[3],
    v1.data[1] * v2.data[2] - v1.data[2] * v2.data[1],
)

cross(v1::UnitVec3, v2::Vec3)::Vec3 = cross(as_vec3(v1), v2)

cross(v1::Vec3, v2::UnitVec3)::Vec3 = cross(v1, as_vec3(v2))

*(v::UnitVec3, s::Float64)::Vec3 = Vec3(s .* v.data)

*(s::Float64, v::UnitVec3)::Vec3 = Vec3(s .* v.data)

-(a::UnitVec3) = UnitVec3(-a.data[1], -a.data[2], -a.data[3])

export Vec3, UnitVec3, length, as_vector, as_vec3, length, normalize, dot, cross, x, y, z

end
