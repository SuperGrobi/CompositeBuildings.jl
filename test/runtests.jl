using CompositeBuildings
using CoolWalksUtils
using ArchGDAL
using DataFrames
using Test

@show ENV

@warn ENV["GITHUB_CI"]

include("OtherLoaders.jl")
include("ShadowCasting.jl")
