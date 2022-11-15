module CompositeBuildings

using CoolWalksUtils
using LightOSM
using LightXML
using JSON
using HTTP
using Formatting
using ArchGDAL
using GeoInterface
using GeoInterfaceRecipes
using DataFrames
using GeoDataFrames
using GeoFormatTypes
using ProgressMeter

export SimpleBuilding,
    BuildingPart,
    CompositeBuilding
include("types.jl")

export download_composite_osm_buildings
include("building_downloaders.jl")


export composite_buildings_from_object,
    composite_buildings_from_file,
    composite_buildings_from_download,
    to_dataframe,
    osm_dfs_from_object,
    osm_dfs_from_file,
    osm_dfs_from_download,
    buildings_from_test_area,
    dfs_from_test_area
include("building_parsers.jl")

export relate_buildings
include("relate_buildings.jl")

export load_british_shapefiles
include("load_other_sources.jl")

end