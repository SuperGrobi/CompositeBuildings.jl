using CompositeBuildings
using LightOSM
using LightXML
using Test

@testset "downloader" begin
    # this is just testing whether we get stuff back from osm.
    # please figure out yourself if it is the correct stuff.
    from_place_osm = download_composite_osm_buildings(:place_name; place_name="mutitjulu, australia");
    @test from_place_osm isa XMLDocument
    from_bbox_osm = download_composite_osm_buildings(:bbox; minlat=-25.38653, minlon=130.99883, maxlat=-25.31478, maxlon=131.08938);
    @test from_bbox_osm isa XMLDocument
    from_point_osm = download_composite_osm_buildings(:point; point=GeoLocation(-25.31478, 131.08938, 0.0), radius=10000)
    @test from_point_osm isa XMLDocument

    from_place_json = download_composite_osm_buildings(:place_name; download_format=:json, place_name="mutitjulu, australia");
    @test from_place_json isa Dict{String, Any}
    from_bbox_json = download_composite_osm_buildings(:bbox; download_format=:json, minlat=-25.38653, minlon=130.99883, maxlat=-25.31478, maxlon=131.08938);
    @test from_bbox_json isa Dict{String, Any}
    from_point_json = download_composite_osm_buildings(:point; download_format=:json, point=GeoLocation(-25.31478, 131.08938, 0.0), radius=10000)
    @test from_point_json isa Dict{String, Any}
end
