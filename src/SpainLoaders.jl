"""
    parse_polygon_string(polystring)

parses a string of the form `"lat1 lon1 lat2 lon2..."` or `"lat1\\tlon1\\tlat2\\tlon2..."`
into an `ArchGDAL` polygon.
"""
function parse_polygon_string(polystring)
    points = split(strip(polystring), [' ', '\t']) .|> s -> parse(Float64, s)
    ArchGDAL.createpolygon(points[2:2:end], points[1:2:end])
end

function parse_region_id(regionstring)
    parse(Int, split(regionstring, " ")[3])
end

function parse_subregion_id(srs)
    parse(Int, split(srs, "-")[1])
end

"""
    parse_spain_xml(url)

Reads an XML Document from the Spanish Cadastral Dataset (see [here](https://www.catastro.minhap.es/INSPIRE/buildings/ES.SDGC.BU.atom.xml) for an example)
and parses it into a dataframe containing information about the regions described within it.
"""
function parse_spain_xml(url)
    xmldoc = HTTP.get(url).body |> String |> LightXML.parse_string
    df = DataFrame("title" => String[], "polygon" => String[], "id" => String[])
    for c in child_nodes(root(xmldoc))  # c is an instance of XMLNode
        if is_elementnode(c) && name(c) == "entry"
            entry = Dict{String,String}()
            for i in child_nodes(c)
                if name(i) in ["title", "polygon", "id"]
                    entry[name(i)] = content(i)
                end
            end
            push!(df, entry)
        end
    end
    free(xmldoc)
    transform!(df, :polygon => ByRow(parse_polygon_string) => :geometry)
    rename!(df, :id => :url)
    select!(df, Not(:polygon))
end

"""
    download_spain_overview()

Downloads and parses the xml file at https://www.catastro.minhap.es/INSPIRE/buildings/ES.SDGC.BU.atom.xml
"""
function download_spain_overview()
    df = parse_spain_xml("https://www.catastro.minhap.es/INSPIRE/buildings/ES.SDGC.BU.atom.xml")
    transform!(df, :title => ByRow(parse_region_id) => :id)
end

"""
    download_spain_region_overview(region_id, spain_overview=download_spain_overview())

Downloads and parses the xml corresponding to the `region_id` from the cadastral dataset.
Can optionally take the result from `download_spain_overview()`, to reduce the number of server calls.
"""
function download_spain_region_overview(region_id, spain_overview=download_spain_overview())
    df = filter(:id => ==(region_id), spain_overview).url[1] |> parse_spain_xml
    transform!(df, :title => ByRow(parse_subregion_id) => :id)
end

"""
    download_spain_subregion(url, savepath)

Downloads the zip file at `url` (element of `download_spain_region_overview(...).url`) to `savepath.zip`,
extracts it to `savepath/raw`, and deletes the zip file.
"""
function download_spain_subregion(url, savepath)
    savename = savepath * ".zip"
    if !ispath(savepath)
        Downloads.download(replace(url, " " => "%20"), savename)
        unzipdir = joinpath(savepath, "raw")
        mkpath(unzipdir)
        run(`unzip $savename -d $unzipdir`)
        rm(savename)
    else
        @warn "The path $savepath already exists."
    end
end

"""
    load_spain_buildings_gml(path; extent=nothing)

Loads the file at `path` with `GeoDataFrames`, and applies some transformations that only make sense if it is a
buildings file from the spanish cadastral dataset.
"""
function load_spain_buildings_gml(path; extent=nothing)
    df = GeoDataFrames.read(path)
    df.myArea = ArchGDAL.geomarea.(df.geometry)
    project_back!(df)

    apply_extent!(df, extent)

    df.nFloors_approx = df.value ./ df.myArea
    select!(
        df, :localId => :id,
        :localId => :building_id,
        :geometry,
        :numberOfFloorsAboveGround => :nFloors,
        :nFloors_approx,
        :value => :area,
        :myArea,
        :currentUse,
        :documentLink,
        :gml_id,
        :informationSystem
    )

    # check if there are some buildings with actual floors. If not, delete the column
    missing_floors = count(ismissing, df.nFloors)
    if missing_floors != nrow(df)
        @info "$(nrow(df) - missing_floors) buildings have a non missing number of floors."
    else
        select!(df, Not(:nFloors))
    end

    # flatten multipolygons to just polygons
    transform!(df, [:geometry, :id] => ByRow(split_multi_poly) => [:geometry, :id])
    df = flatten(df, [:geometry, :id])

    set_observatory!(df, "SpainRawBuildingsObservatory", tz"Europe/Madrid"; source=[:geometry])
    convex_report(df)
    return df
end

"""
    load_spain_parts_gml(path; extent=nothing)

Loads the file at `path` with `GeoDataFrames`, and applies some transformations that only make sense if it is a
buildingparts file from the spanish cadastral dataset.
"""
function load_spain_parts_gml(path; extent=nothing)
    df = GeoDataFrames.read(path)
    dropmissing!(df, :numberOfFloorsAboveGround)
    #filter!(:numberOfFloorsAboveGround => <(70), df)
    df.myArea = ArchGDAL.geomarea.(df.geometry)
    project_back!(df)

    apply_extent!(df, extent; source=[:geometry])

    select!(df, :localId => :id, :geometry, :numberOfFloorsAboveGround => :nFloors, :myArea, :gml_id)
    transform!(df, [:geometry, :id] => ByRow(split_multi_poly) => [:geometry, :id])
    df = flatten(df, [:geometry, :id])
    filter!(:geometry => ArchGDAL.isvalid, df)
    transform!(df, :id => ByRow(id -> split(id, "_part")[1]) => :building_id)

    convex_report(df)
    return df
end

"""
    relate_floors(buildings, buildings_parts)

Infers the number of floors a building in `buildings` might have, given the data present in its constituent `buildings_parts` by various different methods:

- `nFloors_overlap`: average number of floors in all parts, weighed by intersection area (overlap) between each part and the building.
- `nFloors_approx`: given `area` in the dataset divided by area of the footprint (`myArea`). Assumes that `area` is a "usable area".
- `nFloors_part_approx`: given `area` in the dataset divided by the total footprint-area of all parts (`myArea_part`). Assumes that the given area is some kind of "usable area".
- `maxFloors_part`: maximum value of floors in all parts associated with building.
"""
function relate_floors(buildings, buildings_parts)
    project_local!(buildings)
    project_local!(buildings_parts, metadata(buildings, "observatory"))

    all_data = innerjoin(buildings, buildings_parts, on=:building_id, renamecols="" => "_part")
    transform!(all_data, [:geometry, :geometry_part] => ByRow((a, b) -> ArchGDAL.geomarea(ArchGDAL.intersection(a, b))) => :overlap)

    all_data_grouped = groupby(all_data, :id)
    all_data_combined = combine(
        all_data_grouped, names(buildings) .=> first .=> names(buildings),
        :myArea_part => sum => :myArea_part,
        :nFloors_part => maximum => :maxFloors_part,
        [:overlap, :nFloors_part] => ((ol, fl) -> mapreduce(*, +, ol, fl) / sum(ol)) => :nFloors_overlap
    )
    transform!(all_data_combined, [:area, :myArea_part] => ByRow(/) => :nFloors_part_approx)
    filter!(:nFloors_overlap => !isnan, all_data_combined)
    @info "$(count(>(75), all_data_combined.maxFloors_part)) out of $(nrow(all_data_combined)) will be filtered du to too more than 75 levels in a part."
    filter!(:maxFloors_part => <=(75), all_data_combined)

    select!(all_data_combined, :id, :geometry, :nFloors_overlap, :nFloors_approx, :nFloors_part_approx, :area, :myArea, :myArea_part, :currentUse, :documentLink, :maxFloors_part)
    project_back!(all_data_combined)
end

"""
    preprocess_spain_subregion(path; extent=nothing)

Loads buildings and building parts form `path/raw`, and save the result of `relate_floors(...)` to `path/buildings.geojson`
"""
function preprocess_spain_subregion(path; extent=nothing)
    filenames = readdir(joinpath(path, "raw"))
    buildings_name = findfirst(n -> occursin("building.gml", n), filenames)
    parts_name = findfirst(n -> occursin("buildingpart.gml", n), filenames)

    buildings = load_spain_buildings_gml(joinpath(path, "raw", filenames[buildings_name]); extent)
    building_parts = load_spain_parts_gml(joinpath(path, "raw", filenames[parts_name]); extent)
    buildings_with_floors = relate_floors(buildings, building_parts)

    GeoDataFrames.write(joinpath(path, "buildings.geojson"), buildings_with_floors)
    return buildings_with_floors
end

"""
    load_spain_processed_buildings(path; extent=nothing, floor_height=4.0)

loads the files saved by `preprocess_spain_subregion(...)` from `path/buildings.geojson` and adds metadata for projection.

Uses `floor_height` to convert `nFloor_overlap` to building height.

The returned `DataFrame` fulfills the requirements to be used as a source for building data.
"""
function load_spain_processed_buildings(path; extent=nothing, floor_height=4.0)
    filepath = joinpath(path, "buildings.geojson")
    @assert isfile(filepath) "$filepath does not exist."
    df = GeoDataFrames.read(filepath)

    apply_extent!(df, extent; source=[:geometry])

    transform!(df, :nFloors_overlap => ByRow(l -> l * floor_height) => :height)
    metadata!(df, "assumed_floor_height", floor_height; style=:note)

    set_observatory!(df, "SpainBuildingsObservatory", tz"Europe/Madrid"; source=[:geometry])

    convex_report(df)
    check_building_dataframe_integrity(df)
    return df
end