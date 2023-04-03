struct RGB
    r::Float64
    g::Float64
    b::Float64
end

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

struct Vec3
    x::Float64
    y::Float64
    z::Float64
end

struct Sphere
    center::Vec3
    radius::Float64
end

struct Scene
    objects::Vector{Sphere}
end

function render(scene::Scene, size::Tuple{Int,Int})::Image
    result = Image(size)
    spp = 1

    for _ in 1:spp
        for i in 1:size[1]
            for j in 1:size[2]
                result.data[i, j] = RGB(1, 1, 1)
            end
        end
    end

    result
end

function main()
    scene = Scene([Sphere(Vec3(0, 0, 0), 1), Sphere(Vec3(0, 0, 0), 1)])

    result = render(scene, (100, 100))

    save("output", result)
end

main()
