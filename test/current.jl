using CompositeBuildings
using DataFrames
using ArchGDAL
using GeoInterface
using Plots
using ProgressMeter
using Folium
using BenchmarkTools

datapath = joinpath(homedir(), "Desktop/Masterarbeit/CoolWalksAnalysis/data/exp_raw/")



c = load_british_shapefiles(joinpath(datapath, "clifton/clifton.shp"); bbox=(minlon=-1.2, minlat=52.89, maxlon=-1.165, maxlat=52.92))
d = load_british_shapefiles(joinpath(datapath, "clifton/clifton.shp"); bbox=(minlon=-1.2, minlat=52.89, maxlon=-1.165, maxlat=52.92))
filter!(:id => i -> rand() > 0.5, d)

@benchmark relate_buildings(d, c)

b = load_new_york_shapefiles(joinpath(datapath, "manhattan/manhattan.shp"))


p = ArchGDAL.pointonsurface.(b.geometry)
g = b.geometry
names(b)

heights = Set(b.heightroof)
gdf = groupby(b, :heightroof)

msh = filter(i -> nrow(i) > 6, gdf)

msh[1]

smalls = filter(:heightroof => h -> h isa Missing, b)


@showprogress 1 "well..." map(p) do p1
    mapreduce(+, g) do g1
        ArchGDAL.contains(g1, p1)
    end
end



plot(c.geometry[1])
draw(msh[1].geometry; stroke=true, figure_params=Dict(:location => (40.78, -73.97), :zoom_start => 12))
