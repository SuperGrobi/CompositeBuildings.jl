using CompositeBuildings
using Plots

datapath = joinpath(homedir(), "Desktop/Masterarbeit/data/Nottingham/")
buildings = load_british_shapefiles(joinpath(datapath, "Nottingham.shp"); bbox=(minlon=-1.2, minlat=52.89, maxlon=-1.165, maxlat=52.92))

shadows = CompositeBuildings.cast_shadow(buildings, :height_mean, [1.0, -0.5, 0.4])

plot(first(shadows.geometry, 5))