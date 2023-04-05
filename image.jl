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

function save(filepath::String, image::Image)
    open("$filepath.ppm", "w") do io
        println(io, "P3")
        println(io, size(image.data)[1], " ", size(image.data)[2])
        println(io, 255)

        for j in 1:size(image.data)[2]
            for i in 1:size(image.data)[1]
                r = image.data[i, j].r
                if isnan(r)
                    r = 0
                end
                g = image.data[i, j].g
                if isnan(g)
                    g = 0
                end
                b = image.data[i, j].b
                if isnan(b)
                    b = 0
                end

                println(
                    io,
                    round(Int, min(r, 1.0) * 255), " ",
                    round(Int, min(g, 1.0) * 255), " ",
                    round(Int, min(b, 1.0) * 255),
                )
            end
        end
    end

    run(`convert $filepath.ppm $filepath.png`)
end
