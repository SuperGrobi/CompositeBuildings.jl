is_building_part(tags::Dict)::Bool = haskey(tags, "building:part")

function to_dataframe(d::Union{BuildingDict, PartDict}; preserve_all_tags=false)
    # build list of values
    all_tags = Dict{Symbol, Any}()
    first_elem = first(d).second
    all_tags[:id] = typeof(first_elem.id)[]
    all_tags[:geometry] = typeof(first_elem.polygon)[]
    all_tags[:height] = Union{Missing, Float64}[]
    all_tags[:levels] = Union{Missing, Int8}[]
    
    # create DataFrames
    df = DataFrame(all_tags...)
    
    # add all elements as rows
    for (id, elem) in d
        row = Dict{Symbol, Any}()
        row[:id] = elem.id
        row[:geometry] = elem.polygon
        for (tag, value) in elem.tags
            row[Symbol(tag)] = value
        end
        push!(df, row; cols= preserve_all_tags ? :union : :subset)
    end

    bbox = BoundingBox(df.geometry)
    metadata!(df, "center_lon", (bbox.minlon + bbox.maxlon)/2; style=:note)
    metadata!(df, "center_lat", (bbox.minlat + bbox.maxlat)/2; style=:note)
    return df
end

function composite_height(tags::Dict)::Tuple{Union{Float64, Missing}, Union{Float64, Missing}}
    height = get(tags, "height", missing)
    levels = get(tags, "building:levels", missing) !== missing ? tags["building:levels"] : get(tags, "level", missing)
    roof_levels = get(tags, "roof:levels", missing)
    if !(height isa Missing)
        height = height isa String ? max([LightOSM.remove_non_numeric(h) for h in split(height, r"[+^;,-]")]...) : height
    end
    if !(levels isa Missing)
        levels = levels isa String ? round(max([LightOSM.remove_non_numeric(l) for l in split(levels, r"[+^;,-]")]...)) : levels
        levels = levels < 1 ? missing : levels
        # set building height to missing if there is no data.
    end
    if !(roof_levels isa Missing)
        roof_levels = roof_levels isa String ? round(max([LightOSM.remove_non_numeric(l) for l in split(roof_levels, r"[+^;,-]")]...)) : roof_levels
    end


    # ignore if there is no roof level, it is rarely used
    return height, roof_levels isa Missing ? levels : levels + roof_levels
end


empty_poly() = ArchGDAL.createpolygon()


function add_way_to_poly!(poly, way, nodes)
    nds = [nodes[n] for n in way["nodes"]]
    node_tuples = [(i.location.lon, i.location.lat) for i in nds]
    
    linear_ring = ArchGDAL.createlinearring(node_tuples)
    apply_wsg_84!(linear_ring)
    ArchGDAL.addgeom!(poly, linear_ring)
end


function parse_osm_composite_buildings_dict(osm_buildings_dict::AbstractDict; return_invalid = false)::Tuple{BuildingDict, PartDict}
    iv_relation_building = 0
    iv_relation_part = 0
    iv_simple_building = 0
    iv_simple_part = 0
    T = LightOSM.DEFAULT_OSM_ID_TYPE
    # parse all nodes into Node type
    nodes = Dict{T, Node{T}}()
    for node in osm_buildings_dict["node"]
        id = node["id"]
        nodes[id] = Node{T}(
            id,
            GeoLocation(node["lat"], node["lon"]),
            haskey(node, "tags") ? node["tags"] : nothing
        )
    end

    ways = Dict(way["id"] => way for way in osm_buildings_dict["way"])  # for lookup

    added_ways = Set{T}()  # keep track of the ways already added during relation parsing
    buildings = Dict{T, CompositeBuildings.AbstractBuilding{T}}()
    building_parts = Dict{T, BuildingPart{T}}()

    @showprogress 0.1 "parsing relations" for relation in osm_buildings_dict["relation"]
        # parse all buildings with multiple rings
        if haskey(relation, "tags") && LightOSM.is_building(relation["tags"])
            tags = relation["tags"]
            rel_id = relation["id"]
            # throw out all the weird stuff that may be attached to relations
            members = filter(x->x["type"] == "way" && x["role"] in ["outer", "inner"], relation["members"])
            length(members) == 0 && continue
            polygon = empty_poly()
            
            # to be a valid polygon, the outer has to be the first one added
            for member in sort(members, by=x->x["role"] == "outer", rev=true)
                way_id = member["ref"]
                way = ways[way_id]
                # copy tags from way to tags from relation
                haskey(way, "tags") && merge!(tags, way["tags"]) # could potentially overwrite some data
                push!(added_ways, way_id)

                add_way_to_poly!(polygon, way, nodes)
            end
            apply_wsg_84!(polygon)
            
            height, levels = composite_height(tags)
            tags["height"] = height
            tags["levels"] = levels
            !ArchGDAL.isvalid(polygon) && (iv_relation_building += 1)
            buildings[rel_id] = SimpleBuilding{T}(rel_id, polygon, tags)

        # parse all multipolygon parts
        elseif haskey(relation, "tags") && is_building_part(relation["tags"])
            tags = relation["tags"]
            rel_id = relation["id"]
            members = filter(x->x["type"] == "way" && x["role"] in ["outer", "inner"], relation["members"])
            length(members) == 0 && continue
            polygon = empty_poly()

            for member in sort(members, by=x->x["role"] == "outer", rev=true)
                way_id = member["ref"]
                way = ways[way_id]
                # copy tags from way to tags from relation
                haskey(way, "tags") && merge!(tags, way["tags"]) # could potentially overwrite some data
                push!(added_ways, way_id)
                
                add_way_to_poly!(polygon, way, nodes)
            end
            apply_wsg_84!(polygon)

            # TODO: guarantee that relevant tags are present (height, min_height, max_height)...
            !ArchGDAL.isvalid(polygon) &&  (iv_relation_part += 1)
            building_parts[rel_id] = BuildingPart{T}(rel_id, polygon, tags)
            # TODO: maybe refactor this whole thing into a function?
        end
    end

    @showprogress 0.1 "parsing ways" for (way_id, way) in ways
        if haskey(way, "tags") && LightOSM.is_building(way["tags"]) && !(way_id in added_ways)
            tags = way["tags"]
            height, levels = composite_height(tags)
            tags["height"] = height
            tags["levels"] = levels

            polygon = empty_poly()
            add_way_to_poly!(polygon, way, nodes)
            apply_wsg_84!(polygon)
            !ArchGDAL.isvalid(polygon) &&  (iv_simple_building += 1)
            buildings[way_id] = SimpleBuilding{T}(way_id, polygon, tags)

        elseif haskey(way, "tags") && is_building_part(way["tags"]) && !(way_id in added_ways)
            tags = way["tags"]
            # TODO: make sure all relevant tags are present
            # tags["height"] = composite_height(tags)

            polygon = empty_poly()
            add_way_to_poly!(polygon, way, nodes)
            apply_wsg_84!(polygon)
            !ArchGDAL.isvalid(polygon) &&  (iv_simple_part += 1)
            building_parts[way_id] = BuildingPart{T}(way_id, polygon, tags)
        end
    end

    iv_relation_building != 0 && @warn "$iv_relation_building relation buildings are not valid!"
    iv_relation_part != 0 && @warn "$iv_relation_part relation parts are not valid!"
    iv_simple_building != 0 && @warn "$iv_simple_building simple buildings are not valid!"
    iv_simple_part != 0 && @warn "$iv_simple_part simple parts are not valid!"
    total_iv = iv_relation_building + iv_relation_part + iv_simple_building + iv_simple_part
    if return_invalid
        total_iv > 0 && @info "invalid objects WILL be returned."
        return buildings, building_parts
    else
        total_iv > 0 && @info "invalid objects will NOT be returned."
        return filter(x->ArchGDAL.isvalid(x.second.polygon), buildings), filter(x->ArchGDAL.isvalid(x.second.polygon), building_parts)
    end
end

function composite_buildings_from_object(composite_xml_object::XMLDocument; return_invalid=false)::Tuple{BuildingDict, PartDict}
    dict_to_parse = LightOSM.osm_dict_from_xml(composite_xml_object)
    return parse_osm_composite_buildings_dict(dict_to_parse; return_invalid=return_invalid)
end


function composite_buildings_from_object(composite_json_object::AbstractArray; return_invalid=false)::Tuple{BuildingDict, PartDict}
    dict_to_parse = LightOSM.osm_dict_from_json(composite_json_object)
    return parse_osm_composite_buildings_dict(dict_to_parse; return_invalid=return_invalid)
end


function composite_buildings_from_file(file_path::String; return_invalid=false)::Tuple{BuildingDict, PartDict}
    !isfile(file_path) && throw(ArgumentError("File $file_path does not exist"))
    deserializer = LightOSM.file_deserializer(file_path)
    obj = deserializer(file_path)
    return composite_buildings_from_object(obj; return_invalid=return_invalid)
end


function composite_buildings_from_download(download_method::Symbol;
                                           metadata::Bool=false,
                                           download_format::Symbol=:osm,
                                           save_to_file_location::Union{String,Nothing}=nothing,
                                           return_invalid=false,
                                           download_kwargs...
                                           )::Tuple{BuildingDict, PartDict}
    obj = download_composite_osm_buildings(download_method;
                                           metadata=metadata,
                                           download_format=download_format,
                                           save_to_file_location=save_to_file_location,
                                           download_kwargs...)
    return composite_buildings_from_object(obj; return_invalid=false)
end

function osm_dfs_from_object(object; return_invalid=false)
    b, p = composite_buildings_from_object(object; return_invalid=return_invalid)
    b = to_dataframe(b)
    p = to_dataframe(p; preserve_all_tags = true)
    return b, p
end

function osm_dfs_from_file(path; return_invalid=false)
    b, p = composite_buildings_from_file(path; return_invalid=return_invalid)
    b = to_dataframe(b)
    p = to_dataframe(p; preserve_all_tags = true)
    return b, p
end

function osm_dfs_from_download(args...; return_invalid=false, kwargs...)
    b, p = composite_buildings_from_download(args...; return_invalid=return_invalid, kwargs...)
    b = to_dataframe(b)
    p = to_dataframe(p; preserve_all_tags = true)
    return b, p
end

buildings_from_test_area() = composite_buildings_from_download(:bbox; minlat=55.6830369, minlon=12.5905037, maxlat=55.687142, maxlon=12.596064)
dfs_from_test_area() = osm_dfs_from_download(:bbox; minlat=55.6830369, minlon=12.5905037, maxlat=55.687142, maxlon=12.596064)