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
struct MultiPolyBuilding{T} <: AbstractBuilding{T}
    id::T
    polygons::Vector{LightOSM.Polygon{T}}
    tags::AbstractDict{String,Any}
end

"""
Creating Parts, which are basically the same as simpel and multi poly Buildings
"""
const SimplePart = SimpleBuilding
const MultiPolyPart = MultiPolyBuilding


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