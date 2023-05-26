module CompositeBuildings

using CoolWalksUtils
using ArchGDAL
using GeoInterface
using DataFrames
using GeoDataFrames
using GeoFormatTypes
using ProgressMeter
using SpatialIndexing
using HTTP
using Downloads
using LightXML


split_multi_poly(g::ArchGDAL.IGeometry{ArchGDAL.wkbPolygon}, id) = [g], [string(id)]
split_multi_poly(g::ArchGDAL.IGeometry{ArchGDAL.wkbMultiPolygon}, id) = collect(getgeom(g)), string(id) * "_" .* string.(1:ngeom(g))


export relate_buildings
include("relate_buildings.jl")

export load_british_shapefiles, load_new_york_shapefiles
include("OtherLoaders.jl")

export download_spain_overview,
    download_spain_region_overview,
    download_spain_subregion,
    load_spain_buildings_shapefiles,
    load_spain_parts_shapefiles,
    relate_floors,
    preprocess_spain_subregion,
    load_spain_processed_buildings
include("SpainLoaders.jl")

export cast_shadow
include("ShadowCasting.jl")
end