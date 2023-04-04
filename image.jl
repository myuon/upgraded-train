import Base: /

struct RGB
    r::Float64
    g::Float64
    b::Float64
end

/(rgb::RGB, s::Number)::RGB = RGB(rgb.r / s, rgb.g / s, rgb.b / s)

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

        for i in 1:size(image.data)[1]
            for j in 1:size(image.data)[2]
                println(io, round(Int, image.data[i, j].r * 255), " ", round(Int, image.data[i, j].g * 255), " ", round(Int, image.data[i, j].b * 255))
            end
        end
    end

    run(`convert $filepath.ppm $filepath.png`)
end