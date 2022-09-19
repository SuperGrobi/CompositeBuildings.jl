module CompositeBuildings

using LightOSM
using LightXML
using JSON
using HTTP
using Formatting
using ArchGDAL
using GeoInterface
using GeoInterfaceRecipes
using DataFrames

export SimpleBuilding,
    BuildingPart,
    CompositeBuilding
include("types.jl")

export download_composite_osm_buildings
include("building_downloaders.jl")


export composite_buildings_from_object,
    composite_buildings_from_file,
    composite_buildings_from_download,
    buildings_from_test_area,
    to_dataframe
include("building_parsers.jl")

export relate_buildings
include("relate_buildings.jl")
end