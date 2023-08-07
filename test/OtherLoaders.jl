@testitem "load_british_shapefiles" begin
    using DataFrames, ArchGDAL, Extents, CoolWalksUtils
    cd(@__DIR__)
    buildings = load_british_shapefiles("./data/clifton/clifton_test.shp")
    @test nrow(buildings) == 2956
    @test ncol(buildings) == 9
    @test repr(ArchGDAL.getspatialref(first(buildings.geometry))) == repr(OSM_ref[])

    CompositeBuildings.check_building_dataframe_integrity(buildings)

    buildings_cropped = load_british_shapefiles("./data/clifton/clifton_test.shp"; extent=Extent(X=(-1.19, -1.17), Y=(52.89, 52.91)))
    @test nrow(buildings_cropped) == 1715
    @test ncol(buildings_cropped) == 9
    @test repr(ArchGDAL.getspatialref(first(buildings_cropped.geometry))) == repr(OSM_ref[])
    CompositeBuildings.check_building_dataframe_integrity(buildings)
end

@testset "load_new_york_shapefiles" begin
    @test_skip "add local tests to check if loading of new york is happening correctly"
end

@testset "load_spain_shapefiles" begin
    @test_skip "add local tests to check if loading of spain shapefiles is happening correctly"
end