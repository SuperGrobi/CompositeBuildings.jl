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

export download_composite_osm_buildings
include("building_downloaders.jl")


export composite_buildings_from_object,
    composite_buildings_from_file,
    composite_buildings_from_download
include("building_parses.jl")
end
       