using CompositeBuildings
using DataFrames
using ArchGDAL
using GeoInterface
using Plots
using ProgressMeter
using Folium

datapath = joinpath(homedir(), "Desktop/Masterarbeit/CoolWalksAnalysis/data/exp_raw/")


c = load_british_shapefiles(joinpath(datapath, "clifton/clifton.shp"); bbox=(minlon=-1.2, minlat=52.89, maxlon=-1.165, maxlat=52.92))

b = load_new_york_shapefiles(joinpath(datapath, "manhattan/manhattan.shp"))

smalls = filter(:heightroof => h -> h isa Missing, b)


plot(c.geometry[1])
draw(b.geometry; stroke=true)
