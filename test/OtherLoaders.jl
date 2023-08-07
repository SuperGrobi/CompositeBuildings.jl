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

@testitem "load_new_york_shapefiles" begin
    using DataFrames, ArchGDAL, Extents, CoolWalksUtils
    cd(@__DIR__)
    buildings = load_new_york_shapefiles("./data/manhattan/manhattan.shp")
    @test nrow(buildings) == 45977
    @test ncol(buildings) == 16
    @test repr(ArchGDAL.getspatialref(first(buildings.geometry))) == repr(OSM_ref[])

    CompositeBuildings.check_building_dataframe_integrity(buildings)

    buildings_cropped = load_new_york_shapefiles("./data/manhattan/manhattan.shp"; extent=Extent(X=(-73.97, -73.94), Y=(40.6, 40.9)))
    @test nrow(buildings_cropped) == 16674
    @test ncol(buildings_cropped) == 16
    @test repr(ArchGDAL.getspatialref(first(buildings_cropped.geometry))) == repr(OSM_ref[])

    CompositeBuildings.check_building_dataframe_integrity(buildings)
end