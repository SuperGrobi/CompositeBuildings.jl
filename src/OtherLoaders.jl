"""
    load_british_shapefiles(path; bbox=nothing)

loads the shapefiles of the largest cities in great britain, provided by [emu analytics](https://www.emu-analytics.com/products/datapacks)
into dataframes, possibly clipping along a named tuple `BoundingBox` with names `(minlon, minlat, maxlon, maxlat)`.

Returns a dataframe with the columns given in the shapefile, with a few exceptions: `:OBJECTID => :id, :MEAN_mean => :height_mean, :MIN_min => :height_min, :MAX_max => :height_max`.
Polygons are stored in the `geometry` column in `EPSG 4326` crs.

The dataframe has metadata of `center_lat` and `center_lon`, representing the central latitude and longitude of the bounding Box, applied.
"""
function load_british_shapefiles(path; bbox=nothing)
    df = GeoDataFrames.read(path)

    name_map = Dict(
        :OBJECTID => :id,
        :MEAN_mean => :height_mean,
        :MIN_min => :height_min,
        :MAX_max => :height_max
    )
    rename!(df, name_map)

    start_crs = ArchGDAL.getspatialref(df.geometry[1])

    # all transformations to and from EPSG(4326) have to use importEPSG(4326; order: trad)
    # otherwise plotting gets messed up.
    project_back!(df.geometry)
    if bbox === nothing
        bbox = BoundingBox(df.geometry)
    else
        # clip dataframe
        bbox_arch = createpolygon([(bbox.minlon, bbox.minlat), (bbox.minlon, bbox.maxlat), (bbox.maxlon, bbox.maxlat), (bbox.maxlon, bbox.minlat), (bbox.minlon, bbox.minlat)])
        apply_wsg_84!(bbox_arch)
        df = filter(:geometry => x -> intersects(x, bbox_arch), df)
    end

    poly_df = filter(:geometry => x -> x isa ArchGDAL.IGeometry{ArchGDAL.wkbPolygon}, df)
    index = maximum(df.id) + 1
    multipoly_df = filter(:geometry => x -> x isa ArchGDAL.IGeometry{ArchGDAL.wkbMultiPolygon}, df)
    polysplit_df = DataFrame()
    for row in eachrow(multipoly_df)
        for polygon in getgeom(row.geometry)
            row.geometry = polygon
            row.id = index
            push!(polysplit_df, row)
            index += 1
        end
    end

    df = append!(poly_df, polysplit_df)

    metadata!(df, "center_lon", (bbox.minlon + bbox.maxlon) / 2; style=:note)
    metadata!(df, "center_lat", (bbox.minlat + bbox.maxlat) / 2; style=:note)
    return df
end

"""
    load_new_york_shapefiles(path; bbox=nothing)

loads the shapefiles containing building footprints and heights provided by [the city of new york](https://data.cityofnewyork.us/Housing-Development/Building-Footprints/nqwf-w8eh)
into dataframes, possibly clipping along a named tuple `BoundingBox` with names `(minlon, minlat, maxlon, maxlat)`.

Returns a dataframe with the columns given in the shapefile.
Polygons are stored in the `geometry` column in `EPSG 4326` crs.

The dataframe has metadata of `center_lat` and `center_lon`, representing the central latitude and longitude of the bounding Box, applied.
"""
function load_new_york_shapefiles(path; bbox=nothing)
    df = GeoDataFrames.read(path)
    start_crs = ArchGDAL.getspatialref(df.geometry[1])
    project_back!(df.geometry)

    if bbox === nothing
        bbox = BoundingBox(df.geometry)
    else
        # clip dataframe
        bbox_arch = createpolygon([(bbox.minlon, bbox.minlat), (bbox.minlon, bbox.maxlat), (bbox.maxlon, bbox.maxlat), (bbox.maxlon, bbox.minlat), (bbox.minlon, bbox.minlat)])
        apply_wsg_84!(bbox_arch)
        df = filter(:geometry => x -> intersects(x, bbox_arch), df)
    end
    rename!(df, Dict(:doitt_id => :id))
    dropmissing!(df, :heightroof)
    df.heightroof .*= 0.3048  # Americans cant unit.
    metadata!(df, "center_lon", (bbox.minlon + bbox.maxlon) / 2; style=:note)
    metadata!(df, "center_lat", (bbox.minlat + bbox.maxlat) / 2; style=:note)
    return df
end