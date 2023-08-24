@testitem "shadow_cleanup" begin
    using ArchGDAL
    cd(@__DIR__)
    include("./utils/ShadowCastingUtils.jl")
    poly1 = ArchGDAL.createpolygon(square(0, 0, 1))
    poly2 = ArchGDAL.createpolygon([square(0, 0, 1), square(0.1, 0.1, 0.5)])
    multipoly = ArchGDAL.createmultipolygon([[square(0, 0, 1)], [square(2, 0, 1), square(2.2, 0.2, 0.3)]])

    point = ArchGDAL.createpoint(1.0, 2.0)
    line = ArchGDAL.createlinestring(square(3, 3, 2))

    collection_bad0 = collection([poly1, poly2, multipoly, point, line])
    collection_bad1 = collection([poly1, poly2, point, line])
    collection_bad2 = collection([poly1, multipoly, point, line])
    collection_good0 = collection([poly1, line])
    collection_good1 = collection([poly2, point, line])



    @test CompositeBuildings.shadow_cleanup(poly1) == poly1
    @test CompositeBuildings.shadow_cleanup(poly2) == poly2
    @test_throws MethodError CompositeBuildings.shadow_cleanup(multipoly)
    @test_throws MethodError CompositeBuildings.shadow_cleanup(point)
    @test_throws MethodError CompositeBuildings.shadow_cleanup(line)

    @test_throws ArgumentError CompositeBuildings.shadow_cleanup(collection_bad0)
    @test_throws ArgumentError CompositeBuildings.shadow_cleanup(collection_bad1)
    @test_throws ArgumentError CompositeBuildings.shadow_cleanup(collection_bad2)

    @test CompositeBuildings.shadow_cleanup(collection_good0) == poly1
    @test CompositeBuildings.shadow_cleanup(collection_good1) == poly2
end

@testitem "cast_shadows" begin
    using ArchGDAL, Extents, GeoInterface, CoolWalksUtils, DataFrames, TimeZones
    cd(@__DIR__)
    include("./utils/ShadowCastingUtils.jl")

    buildings = load_british_shapefiles("./data/clifton/clifton_test.shp", extent=Extent(X=(-1.19, -1.17), Y=(52.89, 52.91)))
    shadows = cast_shadows(buildings, [0.5, -1, 0.3])
    @test true
    @test nrow(shadows) == nrow(buildings)

    @test_throws AssertionError cast_shadows(buildings, [0.5, -1, -0.3])

    project_local!(buildings)
    shadows.conv = is_convex.(buildings.geometry)

    points = [GeoInterface.coordinates(GeoInterface.getexterior(g)) for g in buildings.geometry]

    shadows_explicit = CompositeBuildings.cast_shadow_explicit.(points, [[-0.5 / 0.3, 1 / 0.3]] .* buildings.height)
    project_local!(shadows)
    shadows.explicit = shadows_explicit
    shadows.area = ArchGDAL.geomarea(shadows.geometry)
    shadows.area_explicit = ArchGDAL.geomarea(shadows.explicit)
    shadows.delta = shadows.area .- shadows.area_explicit

    # all explicit shadows are larger than the simpel ones
    @test all(shadows.delta .< 1e-6)

    filter!(:conv => identity, shadows)

    # all shadows from convex buildings are at most 0.3 sqm smaller than the explicit ones (due to buffering)
    @test all(shadows.delta .> -0.3)

    @test nrow(shadows) == 1624

    cube = ArchGDAL.createpolygon(square(0, 0, 0.0001))
    apply_wsg_84!(cube)
    cube_df = DataFrame(geometry=cube, id=1, height=11.13)  # height is width in projected system
    @test_throws ArgumentError cast_shadows(cube_df, [1, 0, 0.1])  # observatory is not defined

    metadata!(cube_df, "observatory", ShadowObservatory("cubeobs", 0.0, 0.0, tz"Europe/London"))

    shadow_df = cast_shadows(cube_df, [1, 0, 1])
    @test nrow(shadow_df) == 1
    shadow_geom = first(shadow_df.geometry)
    @test ArchGDAL.geomarea(cube) ≈ 0.0001^2
    @test ArchGDAL.geomarea(shadow_geom) ≈ 2e-8 atol = 1e-11
end