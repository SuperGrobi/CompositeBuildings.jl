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

export load_british_shapefiles, load_new_york_shapefiles
include("OtherLoaders.jl")

export cast_shadow
include("ShadowCasting.jl")
end