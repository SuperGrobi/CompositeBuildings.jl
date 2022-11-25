using CompositeBuildings
using CoolWalksUtils
using LightOSM
using LightXML
using Test

function downloader_tests()
    @testset "downloader" begin
        max_retry = 10
        # this is just testing whether we get stuff back from osm.
        # please figure out yourself if it is the correct stuff.
        @rerun max_retry begin
            from_place_osm = download_composite_osm_buildings(:place_name; place_name="mutitjulu, australia");
            @test from_place_osm isa XMLDocument
        end
        @rerun max_retry begin
            from_bbox_osm = download_composite_osm_buildings(:bbox; minlat=-25.38653, minlon=130.99883, maxlat=-25.31478, maxlon=131.08938);
            @test from_bbox_osm isa XMLDocument
        end
        
        @rerun max_retry begin
            from_point_osm = download_composite_osm_buildings(:point; point=GeoLocation(-25.31478, 131.08938), radius=10000)
            @test from_point_osm isa XMLDocument
        end

        @rerun max_retry begin
            from_place_json = download_composite_osm_buildings(:place_name; download_format=:json, place_name="mutitjulu, australia");
            @test from_place_json isa Dict{String, Any}
        end
        
        @rerun max_retry begin
            from_bbox_json = download_composite_osm_buildings(:bbox; download_format=:json, minlat=-25.38653, minlon=130.99883, maxlat=-25.31478, maxlon=131.08938);
            @test from_bbox_json isa Dict{String, Any}
        end
        
        @rerun max_retry begin
            from_point_json = download_composite_osm_buildings(:point; download_format=:json, point=GeoLocation(-25.31478, 131.08938), radius=10000)
            @test from_point_json isa Dict{String, Any}
        end
    end
end
# this test needs some internet connection and may fail randomly, when the server does not manage to respond.
# as long as one test succeeds, things are probably fine.
downloader_tests()