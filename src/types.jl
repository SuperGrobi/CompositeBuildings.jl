const AGPoly = ArchGDAL.IGeometry{ArchGDAL.wkbPolygon}

"""
OSM Building Part, consisting out of one ArchGDAL Polygon
"""
struct BuildingPart{T<:Integer}
    id::T
    polygon::AGPoly
    tags::AbstractDict{String,Any}
end

abstract type AbstractBuilding{T<:Integer} end

"""
Simple OSM Building, consisting out of one ArchGDAL Polygon
"""
struct SimpleBuilding{T} <: AbstractBuilding{T}
    id::T
    polygon::AGPoly
    tags::AbstractDict{String,Any}
end

"""
Composite Building, consisting of a  SimpleBuilding (as a fallback)
and a vector of building parts
"""
struct CompositeBuilding{T} <: AbstractBuilding{T}
    id::T
    baseBuilding::SimpleBuilding{T}
    parts::Vector{BuildingPart{T}}
    tags::AbstractDict{String,Any}
end

const BuildingDict = Dict{Integer, CompositeBuildings.AbstractBuilding}
const PartDict = Dict{Integer, CompositeBuildings.BuildingPart}

height(building::AbstractBuilding)::Union{Missing, Number} = building.tags["height"]
levels(building::AbstractBuilding)::Union{Missing, Number} = building.tags["levels"]

# GeoInterface for building types
GeoInterface.isgeometry(::Type{<:AbstractBuilding}) = true
# set all buildings to be polygons
GeoInterface.geomtrait(::AbstractBuilding) = GeoInterface.PolygonTrait()
# basic querys for ngeom and geom of buildings
GeoInterface.ngeom(::GeoInterface.PolygonTrait, geom::AbstractBuilding)::Integer = GeoInterface.ngeom(geom.polygon)
GeoInterface.getgeom(::GeoInterface.PolygonTrait, geom::SimpleBuilding, i) = GeoInterface.getgeom(geom.polygon, i)  # ArchGDAL is zero base, but subtracts this one its own
GeoInterface.getgeom(::GeoInterface.PolygonTrait, geom::CompositeBuilding, i) = GeoInterface.getgeom(geom.baseBuilding.polygon, i)



# GeoInterface for parts
GeoInterface.isgeometry(::Type{BuildingPart{T}}) where {T} = true
# set all buildingparts to be polygons
GeoInterface.geomtrait(::BuildingPart) = GeoInterface.PolygonTrait()
# basic querys for ngeom and geom of parts
GeoInterface.ngeom(::GeoInterface.PolygonTrait, geom::BuildingPart)::Integer = 1
GeoInterface.getgeom(::GeoInterface.PolygonTrait, geom::BuildingPart, i) = GeoInterface.getgeom(geom.polygon, i)

@enable_geo_plots AbstractBuilding
@enable_geo_plots BuildingPart

GeoInterface.ncoord(::GeoInterface.PolygonTrait, geom::AbstractBuilding) = 2
GeoInterface.ncoord(::GeoInterface.PolygonTrait, geom::BuildingPart) = 2
