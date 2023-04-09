include("src/renderer.jl")

function main()
    obj = load_obj("assets/CornellBox-Empty-CO.obj")
    @show obj

    scene = Scene(
        Camera(Vec3(50.0, 52.0, 220.0), normalize(Vec3(0.0, 1.0, 0.0)), normalize(Vec3(0.0, -0.04, -1.0)), 30),
        30.0,
        [
        #Sphere(Vec3(1e5 + 1, 40.8, 81.6), 1e5, RGB(0.75, 0.25, 0.25), RGB(0.0, 0.0, 0.0), diffuse),
        # Sphere(Vec3(-1e5 + 99, 40.8, 81.6), 1e5, RGB(0.25, 0.25, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
        # Sphere(Vec3(50.0, 40.8, 1e5), 1e5, RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
        # Sphere(Vec3(50.0, 40.8, -1e5 + 250), 1e5, RGB(0.0, 0.0, 0.0), RGB(0.0, 0.0, 0.0), diffuse),
        # Sphere(Vec3(50.0, 1e5, 81.6), 1e5, RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
        # Sphere(Vec3(50.0, -1e5 + 81.6, 81.6), 1e5, RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
        # Sphere(Vec3(65.0, 20.0, 20.0), 20.0, RGB(0.25, 0.75, 0.25), RGB(0.0, 0.0, 0.0), diffuse),
        # Sphere(Vec3(27.0, 16.5, 47.0), 16.5, RGB(0.99, 0.99, 0.99), RGB(0.0, 0.0, 0.0), specular),
        # Sphere(Vec3(77.0, 16.5, 78.0), 16.5, RGB(0.99, 0.99, 0.99), RGB(0.0, 0.0, 0.0), refractive),
        # Sphere(Vec3(50.0, 70.0, 81.6), 5.0, RGB(0.0, 0.0, 0.0), RGB(0.5, 0.5, 0.5), diffuse),
        ],
        [
            Rectangle(Vec3(0.0, 0.0, 0.0), Vec3(0.0, 100.0, 0.0), Vec3(0.0, 0.0, 100.0), RGB(0.3, 0.0, 0.0), RGB(0.0, 0.0, 0.0), diffuse),
            Rectangle(Vec3(100.0, 0.0, 0.0), Vec3(0.0, 100.0, 0.0), Vec3(0.0, 0.0, 100.0), RGB(0.0, 0.3, 0.0), RGB(0.0, 0.0, 0.0), diffuse),
            Rectangle(Vec3(0.0, 0.0, 0.0), Vec3(100.0, 0.0, 0.0), Vec3(0.0, 0.0, 100.0), RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
            Rectangle(Vec3(0.0, 0.0, 0.0), Vec3(0.0, 100.0, 0.0), Vec3(100.0, 0.0, 0.0), RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
            Rectangle(Vec3(0.0, 100.0, 0.0), Vec3(100.0, 0.0, 0.0), Vec3(0.0, 0.0, 100.0), RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse),
            Rectangle(Vec3(40.0, 99.0, 50.0), Vec3(0.0, 0.0, 15.0), Vec3(15.0, 0.0, 0.0), RGB(1.0, 1.0, 1.0), 36.0 * RGB(1.0, 1.0, 1.0), diffuse),
        ],
        [
            rotate_y(Box(Vec3(15.0, 0.0, 20.0), Vec3(30.0, 0.0, 0.0), Vec3(0.0, 0.0, 30.0), Vec3(0.0, 65.0, 0.0), RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse), 2π * 20 / 360),
            rotate_y(Box(Vec3(65.0, 0.0, 55.0), Vec3(25.0, 0.0, 0.0), Vec3(0.0, 0.0, 25.0), Vec3(0.0, 25.0, 0.0), RGB(0.75, 0.75, 0.75), RGB(0.0, 0.0, 0.0), diffuse), 2π * -20 / 360),
        ],
    )

    result = render(scene, (640, 480))

    save("output", result, 2.2, enable_TONE_MAP)
end

main()
