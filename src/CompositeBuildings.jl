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
using TimeZones
using Extents


split_multi_poly(g::ArchGDAL.IGeometry{ArchGDAL.wkbPolygon}, id) = [g], [string(id)]
split_multi_poly(g::ArchGDAL.IGeometry{ArchGDAL.wkbMultiPolygon}, id) = collect(getgeom(g)), string(id) * "_" .* string.(1:ngeom(g))

"""
    convex_report(df)

Little utility to log how many of the geometries in `df` are convex.
"""
function convex_report(df)
    n_conv = sum(is_convex, df.geometry)
    @info "$n_conv out of $(nrow(df)) Buildings are convex. ($(round(100n_conv/nrow(df), digits=1))%)"
end

"""
check_building_dataframe_integrity(df) 

Checks if `df` conforms to the technical requirements needed to be considered as a source for building data.
"""
function check_building_dataframe_integrity(df)
    colnames = Symbol.(names(df))
    needed_names = [:id, :height, :geometry]
    for i in needed_names
        @assert i in colnames "no column of df is named \"$i\"."
    end
    for g in df.geometry
        @assert g isa ArchGDAL.IGeometry{ArchGDAL.wkbPolygon} "not all entries in the :geometry column are ArchGDAL polygons."
    end

    @assert "observatory" in keys(metadata(df)) "the dataframe has no \"observatory\" metadata."
    @assert metadata(df, "observatory") isa ShadowObservatory "the provided obervatory is not of type ShadowObservatory."
end

export relate_buildings
include("relate_buildings.jl")

export load_british_shapefiles, load_new_york_shapefiles
include("OtherLoaders.jl")

export download_spain_overview,
    download_spain_region_overview,
    download_spain_subregion,
    preprocess_spain_subregion,
    load_spain_processed_buildings
include("SpainLoaders.jl")

export cast_shadow
include("ShadowCasting.jl")


# TODO: Rework OtherLoaders
# TODO: Rework ShadowCasting
# TODO: Rework SpainLoaders
# TODO: decide what to do with relate_buildings
end