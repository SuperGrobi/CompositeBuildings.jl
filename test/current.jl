using CompositeBuildings
using DataFrames
using ArchGDAL
using GeoInterface
using Plots
using ProgressMeter
using Folium
using CoolWalksUtils
using Dates
using BenchmarkTools
using GeoDataFrames
using Extents

datapath = joinpath(homedir(), "Desktop/Masterarbeit/CoolWalksAnalysis/data/exp_raw/")



c = load_british_shapefiles(joinpath(datapath, "clifton/clifton.shp"); extent=Extent(X=(-1.2, -1.18), Y=(52.89, 52.92)))
c = load_british_shapefiles(joinpath(datapath, "clifton/clifton.shp"))
d = load_british_shapefiles(joinpath(datapath, "clifton/clifton.shp"); bbox=(minlon=-1.2, minlat=52.89, maxlon=-1.165, maxlat=52.92))
filter!(:id => i -> rand() > 0.5, d)




sundir
@benchmark cast_shadow(c, :height_mean, sundir)

c.conv_g = CompositeBuildings.is_convex.(c.geometry)
project_local!(c)
c.conv_l = CompositeBuildings.is_convex.(c.geometry)

huh2 = filter([:conv_g, :conv_l] => (a, b) -> a != b, c)
huh2.np = [ngeom(getgeom(i, 1)) for i in huh2.geometry]

plot(huh2.geometry[1], ratio=1)
huh2

project_local!(c)
sundir = sunposition(DateTime(2023, 5, 10, 9, 40), 12 |> deg2rad, 55 |> deg2rad, 1)
sundir = [1, 0, 0.1]
s1 = cast_shadow(c, :height_mean, sundir) |> project_local!
s2 = cast_shadow_new(c, :height_mean, sundir) |> project_local!

s1.area = ArchGDAL.geomarea.(s1.geometry)
s1.conv = CompositeBuildings.is_convex.(c.geometry)
s2.area = ArchGDAL.geomarea.(s2.geometry)
s1.delta = s1.area .- s2.area
scatter(s1.area, s2.area)

s2.conv = s1.conv
c.conv = s2.conv
s1c = filter(:conv => !, s1)
s2c = filter(:conv => !, s2)
bc = filter(:conv => !, c)

scatter(s1c.area, s2c.area)

plot(s1c.delta)

begin
    n = 5
    plot(s1c.geometry[n])
    plot!(s2c.geometry[n])
    plot!(filter(:id => ==(s1c.id[n]), c).geometry[1])
end


icg = CompositeBuildings.is_convex.(c.geometry)
project_local!(c)
icl = CompositeBuildings.is_convex.(c.geometry)

all(icg .== icl)

plot(s1c.delta)

huh = filter(:delta => >(0.4), s1c)

begin
    plot(huh.geometry[1], ratio=1)
    plot!(filter(:id => ==(huh.id[1]), s2).geometry[1])
    plot!(filter(:id => ==(huh.id[1]), bc).geometry[1])
end

b5 = filter(:id => ==(huh.id[4]), bc).geometry[1]

CompositeBuildings.is_convex(filter(:id => ==(huh.id[4]), bc).geometry[1])

pid = 3934565
begin
    plot(filter(:id => ==(pid), s1).geometry[1])
    plot!(filter(:id => ==(pid), s2).geometry[1])
    plot!(filter(:id => ==(pid), c).geometry[1])
end

plot(s1.delta)

n = 1
b1 = s1.geometry[n]
b2 = s2.geometry[n]

tl = ArchGDAL.createlinestring([])
problems = filter(:delta => >(100), s1)
bp = problems.geometry[n]
problems.id[n]
bp = filter(:id => ==(pid), s1).geometry[1]
bpn = filter(:id => ==(pid), s2).geometry[1]

project_local!(c)

begin
    plot(bp, ratio=1)
    for i in getgeom(bp)
        plot!(i, lw=4)
    end
    plot!(bpn, alpha=0.4)
    plot!(filter(:id => ==(pid), c).geometry[1])
end

ns = cast_shadow_new(c, :height_mean, sundir)
ort = [-ov,]

n = 1

bt = c.geometry[n]
lower_ring = GeoInterface.getgeom(bt, 1)
points = getgeom(lower_ring) |> y -> hcat((collect(getcoord(x)) for x in y)...)

ngeom(s1.geometry[1])

begin
    plot(s1.geometry[1])
    plot!(getgeom(s1.geometry[1], 1), lw=3)
    plot!(getgeom(s1.geometry[1], 2), lw=3)
    plot!(ns)
    plot!(lower_ring, lw=3)
    scatter!(getgeom(lower_ring, 4))
end


proj_orv = argmax(points' * orv)

begin
    f = draw(s1.geometry, color=:black)
    draw!(f, c.geometry)
end

using Dates


b = load_new_york_shapefiles(joinpath(datapath, "manhattan/manhattan.shp"); extent=Extent(X=(-73.97, -73.94), Y=(40.6, 40.9)))

metadata(b)

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


datapath = joinpath(homedir(), "Desktop/Masterarbeit/CoolWalksAnalysis/data/exp_raw/")
c = load_british_shapefiles(joinpath(datapath, "clifton/clifton.shp"); bbox=(minlon=-1.2, minlat=52.89, maxlon=-1.165, maxlat=52.92))
pid = 3934565
project_local!(c)
problem_building = filter(:id => ==(pid), c).geometry[1]
sun_dir = [1, 0, 0.1]
function cast_shadow_test(building, sun_direction, h=1.5)
    offset_vector = -sun_direction ./ sun_direction[3]
    offset_vector = offset_vector[1:2]
    ortho_vector = [-offset_vector[2], offset_vector[1]]
    CompositeBuildings.extrude_towards(building, offset_vector * h, ortho_vector)
end

function cast_shadow_test_compare(building, sun_direction, h=1.5)
    offset_vector = -sun_direction ./ sun_direction[3]
    offset_vector = offset_vector[1:2]
    ortho_vector = [-offset_vector[2], offset_vector[1]]
    CompositeBuildings.cast_shadow_explicit(building, offset_vector, h)
end

problem_shadow = cast_shadow_test(problem_building, sun_dir)
compare_shadow = cast_shadow_test_compare(problem_building, sun_dir)

begin
    problem_shadow = cast_shadow_test(problem_building, sun_dir)
    compare_shadow = cast_shadow_test_compare(problem_building, sun_dir)
    plot(ratio=1)
    plot!(compare_shadow, c=2)
    plot!(problem_shadow, ratio=1, color=:black, alpha=0.5)
    plot!(problem_building, alpha=0.6)
end



@benchmark cast_shadow(c, :height_mean, sundir)

test_b = project_local!(filter(:id => ==(pid), c)).geometry[1]
points = hcat((collect(getcoord(x)) for x in getgeom(getgeom(test_b, 1)))...)

@benchmark CompositeBuildings.cast_shadow_explicit(test_b, [-10, 0])


@benchmark CompositeBuildings.cast_shadow_explicit(test_b, [-10, 0])
@benchmark CompositeBuildings.cast_shadow_explicit(points, [-10, 0])
@benchmark CompositeBuildings.extrude_simple(points, [-10, 0], [0, -10])

CompositeBuildings.extrude_simple(points, [-10, 0], [0, -10]) |> plot

@profview for i in 1:70000
    CompositeBuildings.extrude_simple(points, [-10, 0], [0, -10])
end

@view(points[:, 3]) + [100000, 100000]

sdf = download_spain_overview()

rdf = download_spain_region_overview(2)

begin
    f = draw()
    for i in eachrow(rdf)
        draw!(f, i.geometry, stroke=true, fill_opacity=0, tooltip=i.title, popup=i.title)
    end
    fit_bounds!(f)
end
using Downloads

download_spain_subregion(filter(:id => ==(2078), rdf).url[1], joinpath(datapath, "spain/2078"))

spain_df = load_spain_buildings_shapefiles(joinpath(datapath, "spain/2078/raw/A.ES.SDGC.BU.02078.building.gml"))
spain_parts_df = load_spain_parts_shapefiles(joinpath(datapath, "spain/2078/raw/A.ES.SDGC.BU.02078.buildingpart.gml"))

preprocess_spain_subregion(joinpath(datapath, "spain", "2078"))


draw(spain_df[3, :].geometry)

b1 = spain_df[3, :].geometry

ArchGDAL.geomarea.(getgeom(b1))

names(spain_df)
using CoolWalksUtils

project_back!(spain_df)

draw(spain_df.geometry)

spain_df.geomtype = typeof.(spain_df.geometry)

spain_df.ng = ngeom.(spain_df.geometry)
spain_df

groupby(spain_df, :geomtype)

using Plots
begin
    histogram(spain_df.floor_approx)
    vline!([1, 2, 3])
end

draw(spain_df[5, :geometry])

spain_df

spain_test = transform(groupby(spain_df, :geomtype), [:geometry, :id] => ByRow(split_multi_poly) => [:sg, :sid])
flatten(spain_test, [:sg, :sid])

begin
    f = draw(spain_df[7, :geometry])
    for i in eachrow(spain_df)
        #draw!(f, i.geometry, tooltip=i.id)
    end
    n = 6
    #draw!(f, spain_df[1, :geometry], color=:green)
    for i in eachrow(spain_parts_df[1:n, :])
        #draw!(f, i.geometry, color=[:blue, :green, :red][i.nFloors+1], tooltip=string(i.nFloors, " ", i.id))
    end
    #fit_bounds!(f, collect(eachrow(b)))
    f
end

b = f.obj.get_bounds()

floors = relate_floors(spain_df, spain_parts_df)


floors[4, :documentLink]

floors[1706, :documentLink]

combine(floors, [:area, :myArea] .=> first .=> [:area, :myArea], :myArea_part => sum => :myArea_part)

crs(floors)


GeoDataFrames.write(joinpath(datapath, "test.geojson"), floors)
GeoDataFrames.read(joinpath(datapath, "2078", "buildings.geojson"))
GeoDataFrames.read()

drivers = DataFrame(:name => keys(ArchGDAL.listdrivers()) |> collect, :description => values(ArchGDAL.listdrivers()) |> collect)

draw(floors.geometry)

bs = load_spain_processed_buildings((joinpath(datapath, "spain", "2078")))


using Dates
using CoolWalksUtils
using GeoInterface

# REWORK THINGS
c = load_british_shapefiles(joinpath(datapath, "clifton/clifton.shp"))
b = load_new_york_shapefiles(joinpath(datapath, "manhattan/manhattan.shp"))

using BenchmarkTools

cast_shadows(c, DateTime(2023, 8, 7, 14, 30))

cast_shadows(b, DateTime(2023, 8, 7, 14, 30))

@benchmark cast_shadows(c, DateTime(2023, 8, 7, 14, 30))


3


@benchmark cast_shadows(b, DateTime(2023, 8, 7, 14, 30))