abstract type AbstractBuilding{T<:Integer} end

"""
Simple OSM Building, consisting out of one single (outer) Polygon
"""
struct SimpleBuilding{T} <: AbstractBuilding{T}
    id::T
    polygon::LightOSM.Polygon{T}
    tags::AbstractDict{String,Any}
end

"""
More complex OSM Building, consisting out of multiple inner and outer Polygons
"""
# TODO: refactor typ name to something that actually means "polygon with more than on line" building
# rather than collection of multiple polygons (wich might themselves consist of multiple lines...)
struct MultiPolyBuilding{T} <: AbstractBuilding{T}
    id::T
    polygons::Vector{LightOSM.Polygon{T}}
    tags::AbstractDict{String,Any}
end

abstract type AbstractPart{T<:Integer} end
"""
Simple OSM Building Part, consisting out of one single (outer) Polygon
"""
struct SimplePart{T} <: AbstractPart{T}
    id::T
    polygon::LightOSM.Polygon{T}
    tags::AbstractDict{String,Any}
end

"""
More complex OSM Building Part, consisting out of multiple inner and outer Polygons
"""
# TODO: same as with MultiPolyBuilding
struct MultiPolyPart{T} <: AbstractPart{T}
    id::T
    polygons::Vector{LightOSM.Polygon{T}}
    tags::AbstractDict{String,Any}
end


"""
Composite Building, consisting of a non composite building (as a fallback)
and a vector of building parts
"""
struct CompositeBuilding{T} <: AbstractBuilding{T}
    id::T
    baseBuilding::Union{SimpleBuilding{T},MultiPolyBuilding{T}}
    parts::Vector{Union{SimplePart{T},MultiPolyPart{T}}}
    tags::AbstractDict{String,Any}
end

height(building::AbstractBuilding)::Union{Missing, Number} = building.tags["height"]
levels(building::AbstractBuilding)::Union{Missing, Number} = building.tags["levels"]

# GeoInterface for building types
GeoInterface.isgeometry(::AbstractBuilding) = true

# set all buildings to be polygons
GeoInterface.geomtrait(::AbstractBuilding) = GeoInterface.PolygonTrait()

# basic querys for geom and geom of simple building
GeoInterface.ngeom(::GeoInterface.PolygonTrait, geom::SimpleBuilding)::Integer = 1
GeoInterface.getgeom(::GeoInterface.PolygonTrait, geom::SimpleBuilding, i) = geom.polygon

# basic querys for n geom and geom of multipolybuilding
GeoInterface.ngeom(::GeoInterface.PolygonTrait, geom::MultiPolyBuilding)::Integer = length(geom.polygons)
GeoInterface.getgeom(::GeoInterface.PolygonTrait, geom::MultiPolyBuilding, i) = geom.polygons[i]


# set all buildingparts to be polygons
GeoInterface.geomtrait(::AbstractPart) = GeoInterface.PolygonTrait()

# basic querys for geom and geom of simple Part
GeoInterface.ngeom(::GeoInterface.PolygonTrait, geom::SimplePart)::Integer = 1
GeoInterface.getgeom(::GeoInterface.PolygonTrait, geom::SimplePart, i) = geom.polygon

# basic querys for n geom and geom of multipolyPart
GeoInterface.ngeom(::GeoInterface.PolygonTrait, geom::MultiPolyPart)::Integer = length(geom.polygons)
GeoInterface.getgeom(::GeoInterface.PolygonTrait, geom::MultiPolyPart, i) = geom.polygons[i]

