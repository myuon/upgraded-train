import Base: +
import Base: *
import Base: /

struct RGB
    r::Float64
    g::Float64
    b::Float64
end

+(rgb1::RGB, rgb2::RGB)::RGB = RGB(rgb1.r + rgb2.r, rgb1.g + rgb2.g, rgb1.b + rgb2.b)

*(rgb::RGB, s::Number)::RGB = RGB(rgb.r * s, rgb.g * s, rgb.b * s)

*(s::Number, rgb::RGB)::RGB = RGB(rgb.r * s, rgb.g * s, rgb.b * s)

/(rgb::RGB, s::Number)::RGB = RGB(rgb.r / s, rgb.g / s, rgb.b / s)

*(rgb1::RGB, rgb2::RGB)::RGB = RGB(rgb1.r * rgb2.r, rgb1.g * rgb2.g, rgb1.b * rgb2.b)

struct Image
    data::Array{RGB,2}

    function Image(data::Array{RGB,2})
        new(data)
    end

    function Image(size::Tuple{Int,Int})
        data = Array{RGB,2}(undef, size[1], size[2])
        for i in 1:size[1]
            for j in 1:size[2]
                data[i, j] = RGB(0, 0, 0)
            end
        end

        new(data)
    end
end

function to_color_value(value::Float64, gamma::Float64)::Int
    if isnan(value)
        return 0
    end

    return round(Int, max(min(value, 1.0), 0.0)^(1.0 / gamma) * 255)
end

function save(filepath::String, image::Image, gamma::Float64)
    open("$filepath.ppm", "w") do io
        println(io, "P3")
        println(io, size(image.data)[1], " ", size(image.data)[2])
        println(io, 255)

        for j in 1:size(image.data)[2]
            for i in 1:size(image.data)[1]
                r = to_color_value(image.data[i, j].r, gamma)
                g = to_color_value(image.data[i, j].g, gamma)
                b = to_color_value(image.data[i, j].b, gamma)

                println(io, r, " ", g, " ", b)
            end
        end
    end

    run(`convert $filepath.ppm $filepath.png`)
end
