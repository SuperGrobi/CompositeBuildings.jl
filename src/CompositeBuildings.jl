module CompositeBuildings

using CoolWalksUtils
using ArchGDAL
using GeoInterface
using DataFrames
using GeoDataFrames
using GeoFormatTypes
using ProgressMeter

export relate_buildings
include("relate_buildings.jl")

export load_british_shapefiles
include("load_other_sources.jl")

export cast_shadow
include("ShadowCasting.jl")
end