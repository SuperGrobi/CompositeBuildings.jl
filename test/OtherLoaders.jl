@testset "load_british_shapefiles" begin
    buildings = load_british_shapefiles("./data/clifton/clifton_test.shp")
    @test nrow(buildings) == 2989
    @test ncol(buildings) == 9
    @test repr(ArchGDAL.getspatialref(first(buildings.geometry))) == repr(OSM_ref[])
    
    buildings_cropped = load_british_shapefiles("./data/clifton/clifton_test.shp", bbox=(minlon=-1.19, minlat=52.89, maxlon=-1.17, maxlat=52.91))
    @test nrow(buildings_cropped) == 1773
    @test ncol(buildings_cropped) == 9
    @test repr(ArchGDAL.getspatialref(first(buildings_cropped.geometry))) == repr(OSM_ref[])
end