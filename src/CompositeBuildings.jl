module CompositeBuildings

using LightOSM
using LightXML
using JSON
using HTTP
using Formatting
using ArchGDAL
using GeoInterface


export SimpleBuilding,
    BuildingPart,
    CompositeBuilding
include("types.jl")

export download_composite_osm_buildings
include("building_downloaders.jl")


export composite_buildings_from_object,
    composite_buildings_from_file,
    composite_buildings_from_download,
    buildings_from_test_area
include("building_parsers.jl")
end
       