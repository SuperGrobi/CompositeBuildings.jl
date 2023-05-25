function download_spain_overview()
    df = parse_spain_xml("https://www.catastro.minhap.es/INSPIRE/buildings/ES.SDGC.BU.atom.xml")
    transform!(df, :title => parse_region_id => :id)
end

function download_spain_region_overview(region_id, spain_overview=download_spain_overview())
    df = filter(:id => ==(region_id), spain_overview).url[1] |> parse_spain_xml
    transform!(df, :title => parse_subregion_id => :id)
end

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
    transform!(df, :polygon => parse_polygon_strings => :geometry)
    rename!(df, :id => :url)
    select!(df, Not(:polygon))
end

function parse_polygon_strings(polystrings)
    map(polystrings) do polystring
        points = split(strip(polystring), [' ', '\t']) .|> s -> parse(Float64, s)
        ArchGDAL.createpolygon(points[2:2:end], points[1:2:end])
    end
end

function parse_region_id(regionstrings)
    map(regionstrings) do regionstring
        parse(Int, split(regionstring, " ")[3])
    end
end

function parse_subregion_id(sregstrings)
    map(sregstrings) do srs
        parse(Int, split(srs, "-")[1])
    end
end

function download_spain_subregion(url, savepath)
    savename = savepath * ".zip"
    if !ispath(savepath)
        Downloads.download(replace(url, " " => "%20"), savename)
        run(`unzip $savename -d $savepath`)
        rm(savename)
    else
        @warn "The path $savepath already exists."
    end
end

function load_spain_shapefiles(path; bbox=nothing)
    df = GeoDataFrames.read(path)
    df.myarea = ArchGDAL.geomarea.(df.geometry)
    project_back!(df)

    if bbox === nothing
        bbox = BoundingBox(df.geometry)
    else
        # clip dataframe
        bbox_arch = createpolygon([(bbox.minlon, bbox.minlat), (bbox.minlon, bbox.maxlat), (bbox.maxlon, bbox.maxlat), (bbox.maxlon, bbox.minlat), (bbox.minlon, bbox.minlat)])
        apply_wsg_84!(bbox_arch)
        filter!(:geometry => x -> intersects(x, bbox_arch), df)
    end
    select!(df, :geometry, :informationSystem, :localId => :id, :currentUse, :numberOfFloorsAboveGround => :nFloors, :documentLink, :value => :area, :myarea)
    df.floor_approx = df.area ./ df.myarea

    transform!(df, [:geometry, :id] => ByRow(split_multi_poly) => [:geometry, :id])
    df = flatten(df, [:geometry, :id])

    metadata!(df, "center_lon", (bbox.minlon + bbox.maxlon) / 2; style=:note)
    metadata!(df, "center_lat", (bbox.minlat + bbox.maxlat) / 2; style=:note)
    convex_report(df)
    return df
end

function load_spain_parts_shapefiles(path; bbox=nothing)

end