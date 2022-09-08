module CompositeBuildings

using LightOSM
using LightXML
using JSON
using HTTP
using Formatting

export SimpleBuilding,
    MultiPolyBuilding,
    SimplePart,
    MultiPolyPart,
    CompositeBuilding
include("types.jl")

export download_osm_composite_buildings
include("building_downloaders.jl")
end
