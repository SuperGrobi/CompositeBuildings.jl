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
        bbox, _ = bounding_box(df.geometry)
    else
        # clip dataframe
        bbox = createpolygon([(bbox.minlon, bbox.minlat), (bbox.minlon, bbox.maxlat), (bbox.maxlon, bbox.maxlat), (bbox.maxlon, bbox.minlat), (bbox.minlon, bbox.minlat)])
        apply_wsg_84!(bbox)
        df = filter(:geometry => x -> intersects(x, bbox), df)
    end
    metadata!(df, :center_lon, (bbox.minlon + bbox.maxlon)/2; style=:note)
    metadata!(df, :center_lat, (bbox.minlat + bbox.maxlat)/2; style=:note)
    return df
end