"""

    parse_polygon_string(polystring)

parses a string of the form `"lat1 lon1 lat2 lon2..."` or `"lat1\tlon1\tlat2\tlon2..."`
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

Reads an XML Document from the Spanish Cadastral Dataset (see (here)[https://www.catastro.minhap.es/INSPIRE/buildings/ES.SDGC.BU.atom.xml] for an example)
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

    load_spain_buildings_gml(path; bbox=nothing)

Loads the file at `path` with `GeoDataFrames`, and applies some transformations that only make sense if it is a
buildings file from the spanish cadastral dataset.
"""
function load_spain_buildings_gml(path; bbox=nothing)
    df = GeoDataFrames.read(path)
    df.myArea = ArchGDAL.geomarea.(df.geometry)
    project_back!(df)

    if bbox === nothing
        bbox = BoundingBox(df.geometry)
    else
        # clip dataframe
        bbox_arch = createpolygon([(bbox.minlon, bbox.minlat), (bbox.minlon, bbox.maxlat), (bbox.maxlon, bbox.maxlat), (bbox.maxlon, bbox.minlat), (bbox.minlon, bbox.minlat)])
        apply_wsg_84!(bbox_arch)
        filter!(:geometry => x -> intersects(x, bbox_arch), df)
    end
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

    metadata!(df, "center_lon", (bbox.minlon + bbox.maxlon) / 2; style=:note)
    metadata!(df, "center_lat", (bbox.minlat + bbox.maxlat) / 2; style=:note)
    convex_report(df)
    return df
end

"""

    load_spain_parts_gml(path; bbox=nothing)

Loads the file at `path` with `GeoDataFrames`, and applies some transformations that only make sense if it is a
buildingparts file from the spanish cadastral dataset.
"""
function load_spain_parts_gml(path; bbox=nothing)
    df = GeoDataFrames.read(path)
    dropmissing!(df, :numberOfFloorsAboveGround)
    df.myArea = ArchGDAL.geomarea.(df.geometry)
    project_back!(df)

    if bbox === nothing
        bbox = BoundingBox(df.geometry)
    else
        # clip dataframe
        bbox_arch = createpolygon([(bbox.minlon, bbox.minlat), (bbox.minlon, bbox.maxlat), (bbox.maxlon, bbox.maxlat), (bbox.maxlon, bbox.minlat), (bbox.minlon, bbox.minlat)])
        apply_wsg_84!(bbox_arch)
        filter!(:geometry => x -> intersects(x, bbox_arch), df)
    end
    select!(df, :localId => :id, :geometry, :numberOfFloorsAboveGround => :nFloors, :myArea, :gml_id)
    transform!(df, [:geometry, :id] => ByRow(split_multi_poly) => [:geometry, :id])
    df = flatten(df, [:geometry, :id])
    transform!(df, :id => ByRow(id -> split(id, "_part")[1]) => :building_id)
    return df
end

"""

    relate_floors(buildings, buildings_parts)

Infers the number of floors a building in `buildings` might have, given the data present in the its constituent `buildings_parts` by various different methods.
"""
function relate_floors(buildings, buildings_parts)
    project_local!(buildings)
    project_local!(buildings_parts, metadata(buildings, "center_lon"), metadata(buildings, "center_lat"))
    all_data = innerjoin(buildings, buildings_parts, on=:building_id, renamecols="" => "_part")
    transform!(all_data, [:geometry, :geometry_part] => ByRow((a, b) -> ArchGDAL.geomarea(ArchGDAL.intersection(a, b))) => :overlap)
    all_data_grouped = groupby(all_data, :id)
    all_data_combined = combine(
        all_data_grouped, names(buildings) .=> first .=> names(buildings),
        :myArea_part => sum => :myArea_part,
        [:overlap, :nFloors_part] => ((ol, fl) -> mapreduce(*, +, ol, fl) / sum(ol)) => :nFloors_overlap
    )
    transform!(all_data_combined, [:area, :myArea_part] => ByRow(/) => :nFloors_part_approx)

    select!(all_data_combined, :id, :geometry, :nFloors_overlap, :nFloors_approx, :nFloors_part_approx, :area, :myArea, :myArea_part, :currentUse, :documentLink)
    project_back!(all_data_combined)
end

"""

    preprocess_spain_subregion(path; bbox=nothing)


Loads buildings and building parts form `path/raw`, and save the result of `relate_floors(...)` to `path/buildings.geojson`
"""
function preprocess_spain_subregion(path; bbox=nothing)
    filenames = readdir(joinpath(path, "raw"))
    buildings_name = findfirst(n -> occursin("building.gml", n), filenames)
    parts_name = findfirst(n -> occursin("buildingpart.gml", n), filenames)

    buildings = load_spain_buildings_gml(joinpath(path, "raw", filenames[buildings_name]); bbox=bbox)
    building_parts = load_spain_parts_gml(joinpath(path, "raw", filenames[parts_name]); bbox=bbox)
    buildings_with_floors = relate_floors(buildings, building_parts)
    GeoDataFrames.write(joinpath(path, "buildings.geojson"), buildings_with_floors)
    return buildings_with_floors
end

"""

    load_spain_processed_buildings(path; bbox=nothing)

loads the files saved by `preprocess_spain_subregion(...)` from `path/buildings.geojson` and adds metadata for projection.
"""
function load_spain_processed_buildings(path; bbox=nothing)
    filepath = joinpath(path, "buildings.geojson")
    @assert isfile(filepath) "$filepath does not exist."
    @show filepath
    df = GeoDataFrames.read(filepath)
    if bbox === nothing
        bbox = BoundingBox(df.geometry)
    else
        # clip dataframe
        bbox_arch = createpolygon([(bbox.minlon, bbox.minlat), (bbox.minlon, bbox.maxlat), (bbox.maxlon, bbox.maxlat), (bbox.maxlon, bbox.minlat), (bbox.minlon, bbox.minlat)])
        apply_wsg_84!(bbox_arch)
        filter!(:geometry => x -> intersects(x, bbox_arch), df)
    end
    metadata!(df, "center_lon", (bbox.minlon + bbox.maxlon) / 2; style=:note)
    metadata!(df, "center_lat", (bbox.minlat + bbox.maxlat) / 2; style=:note)
    convex_report(df)
    return df
end