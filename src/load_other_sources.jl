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

    # all transformations to and from EPSG(4326) have to use importEPSG(5326; order: trad)
    # otherwise plotting gets messed up.
    target_crs = ArchGDAL.importEPSG(4326; order=:trad)
    ArchGDAL.createcoordtrans(start_crs, target_crs) do trans
        for geo in df.geometry
            ArchGDAL.transform!(geo, trans)
        end
    end
    if bbox === nothing
        return df
    else
        # clip dataframe
        bbox = createpolygon([(bbox.minlon, bbox.minlat), (bbox.minlon, bbox.maxlat), (bbox.maxlon, bbox.maxlat), (bbox.maxlon, bbox.minlat), (bbox.minlon, bbox.minlat)])
        apply_wsg_84!(bbox)
        df = filter(:geometry => x -> intersects(x, bbox), df)
        return df

    end
end

function bounding_box(geo_colunm)
    boxes = ArchGDAL.boundingbox.(geo_colunm)
    min_lat = Inf
    min_lon = Inf
    max_lat = -Inf
    max_lon = -Inf
    for box in boxes
        for point in GeoInterface.getpoint(box)
            lat = getcoord(point, 2)
            lon = getcoord(point, 1)
            min_lat > lat && (min_lat = lat)
            max_lat < lat && (max_lat = lat)
            min_lon > lon && (min_lon = lon)
            max_lon < lon && (max_lon = lon)
        end
    end
    box = createpolygon([(min_lon, min_lat), (min_lon, max_lat), (max_lon, max_lat), (max_lon, min_lat), (min_lon, min_lat)])
    apply_wsg_84!(box)
    return box
end