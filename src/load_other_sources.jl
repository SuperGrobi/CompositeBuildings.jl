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
        bbox = BoundingBox(df.geometry)
    else
        # clip dataframe
        bbox_arch = createpolygon([(bbox.minlon, bbox.minlat), (bbox.minlon, bbox.maxlat), (bbox.maxlon, bbox.maxlat), (bbox.maxlon, bbox.minlat), (bbox.minlon, bbox.minlat)])
        apply_wsg_84!(bbox_arch)
        df = filter(:geometry => x -> intersects(x, bbox_arch), df)
    end

    poly_df = filter(:geometry=>x->x isa ArchGDAL.IGeometry{ArchGDAL.wkbPolygon}, df)
    index = maximum(df.id) + 1
    multipoly_df = filter(:geometry=>x->x isa ArchGDAL.IGeometry{ArchGDAL.wkbMultiPolygon}, df)
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

    metadata!(df, "center_lon", (bbox.minlon + bbox.maxlon)/2; style=:note)
    metadata!(df, "center_lat", (bbox.minlat + bbox.maxlat)/2; style=:note)
    return df
end