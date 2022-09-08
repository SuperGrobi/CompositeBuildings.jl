module CompositeBuildings
using LightOSM
# Write your package code here.
export SimpleBuilding,
    MultiPolyBuilding,
    SimplePart,
    MultiPolyPart,
    CompositeBuilding
include("types.jl")

end
