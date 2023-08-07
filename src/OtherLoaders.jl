"""
    load_british_shapefiles(path; extent=nothing)

loads the shapefiles of the largest cities in great britain, provided by [emu analytics](https://www.emu-analytics.com/products/datapacks)
into a `DataFrame`.

# arguments
- `path`: Path to the file with the dataset
- `extent`: `Extents.Extent`, specifying a clipping range for the Dataset. Use `X` for `lon` and `Y` for `lat`.

Returns a dataframe with the columns given in the shapefile, with a few exceptions:
- `:OBJECTID => :id`
- `:MEAN_mean => :height`
- `:MIN_min => :height_min`
- `:MAX_max => :height_max`

Polygons are stored in the `geometry` column in `EPSG 4326` crs. Only rows where `:height > 0` are returned.

The dataframe has a metadata tag `observatory`, containing the relevant center.
"""
function load_british_shapefiles(path; extent=nothing)
    df = GeoDataFrames.read(path)

    name_map = Dict(
        :OBJECTID => :id,
        :MEAN_mean => :height,
        :MIN_min => :height_min,
        :MAX_max => :height_max
    )
    rename!(df, name_map)
    dropmissing!(df, :height)
    filter!(:height => >(0), df)

    # all transformations to and from EPSG(4326) have to use importEPSG(4326; order: trad)
    # otherwise plotting gets messed up.
    project_back!(df.geometry)


    transform!(df, [:geometry, :id] => ByRow(split_multi_poly) => [:geometry, :id])
    df = flatten(df, [:geometry, :id])

    apply_extent!(df, extent; source=[:geometry])
    set_observatory!(df, "BritishBuildingsObservatory", tz"Europe/London"; source=[:geometry])

    convex_report(df)
    check_building_dataframe_integrity(df)
    return df
end

"""
    load_new_york_shapefiles(path; extent=nothing)

loads the shapefiles containing building footprints and heights provided by [the city of new york](https://data.cityofnewyork.us/Housing-Development/Building-Footprints/nqwf-w8eh)
into a `DataFrame`.

# arguments
- `path`: Path to the file with the dataset
- `extent`: `Extents.Extent`, specifying a clipping range for the Dataset. Use `X` for `lon` and `Y` for `lat`.

Returns a dataframe with the columns given in the shapefile, only rows where `heightroof` is not `missing` and larger than 0 are returned.
Polygons are stored in the `geometry` column in `EPSG 4326` crs.

The dataframe conforms to the requirements needed to be a source for buildings.
"""
function load_new_york_shapefiles(path; extent=nothing)
    df = GeoDataFrames.read(path)

    dropmissing!(df, :heightroof)
    filter!(:heightroof => >(0), df)

    project_back!(df.geometry)
    apply_extent!(df, extent; source=[:geometry])

    rename!(df, Dict(:doitt_id => :id, :heightroof => :height))
    transform!(df, :height => ByRow(h -> h * 0.3048) => :height)  # Americans cant unit.

    set_observatory!(df, "NewYorkBuildingsObservatory", tz"America/New_York"; source=[:geometry])

    convex_report(df)
    check_building_dataframe_integrity(df)
    return df
end