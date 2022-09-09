function composite_height(tags::Dict)::Number
    height = get(tags, "height", nothing)
    levels = get(tags, "building:levels", nothing) !== nothing ? tags["building:levels"] : get(tags, "level", nothing)

    if height !== nothing
        return height isa String ? max([LightOSM.remove_non_numeric(h) for h in split(height, r"[+^;,-]")]...) : height
    elseif levels !== nothing
        levels = levels isa String ? round(max([LightOSM.remove_non_numeric(l) for l in split(levels, r"[+^;,-]")]...)) : levels
        levels = levels == 0 ? rand(1:LightOSM.DEFAULT_MAX_BUILDING_LEVELS[]) : levels
    else
        # set building height to 0 if there is no data.
        # TODO: decide on how to handle missing height data
        levels = 0  # rand(1:DEFAULT_MAX_BUILDING_LEVELS[])
    end

    return levels * LightOSM.DEFAULT_BUILDING_HEIGHT_PER_LEVEL[]
end

function parse_osm_composite_buildings_dict(osm_buildings_dict::AbstractDict)::Dict{Integer, CompositeBuildings.AbstractBuilding}
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

    for relation in osm_buildings_dict["relation"]
        if haskey(relation, "tags") && LightOSM.is_building(relation["tags"])
            tags = relation["tags"]
            rel_id = relation["id"]
            members = relation["members"]
            
            polygons = Vector{LightOSM.Polygon{T}}()
            for member in members
                way_id = member["ref"]
                way = ways[way_id]

                # copy tags from way to tags from relation
                haskey(way, "tags") && merge!(tags, way["tags"]) # could potentially overwrite some data
                push!(added_ways, way_id)

                is_outer = member["role"] == "outer" ? true : false
                nds = [nodes[n] for n in way["nodes"]]
                push!(polygons, LightOSM.Polygon(way_id, nds, is_outer))
            end

            tags["height"] = composite_height(tags)
            sort!(polygons, by = x -> x.is_outer, rev=true) # sorting so outer polygon is always first
            buildings[rel_id] = MultiPolyBuilding{T}(rel_id, polygons, tags)
        end
    end

    for (way_id, way) in ways
        is_outer = true
        if haskey(way, "tags") && LightOSM.is_building(way["tags"]) && !(way_id in added_ways)
            tags = way["tags"]
            tags["height"] = composite_height(tags)
            nds = [nodes[n] for n in way["nodes"]]
            polygon = LightOSM.Polygon(way_id, nds, is_outer)
            buildings[way_id] = SimpleBuilding{T}(way_id, polygon, tags)
        end
    end
    return buildings
end

function composite_buildings_from_object(composite_xml_object::XMLDocument)::Dict{Integer, CompositeBuildings.AbstractBuilding{Integer}}
    dict_to_parse = LightOSM.osm_dict_from_xml(composite_xml_object)
    return parse_osm_composite_buildings_dict(dict_to_parse)
end


function composite_buildings_from_object(composite_json_object::AbstractArray)::Dict{Integer, CompositeBuildings.AbstractBuilding{Integer}}
    dict_to_parse = LightOSM.osm_dict_from_json(composite_json_object)
    return parse_osm_composite_buildings_dict(dict_to_parse)
end


function composite_buildings_from_file(file_path::String)::Dict{Integer, CompositeBuildings.AbstractBuilding{Integer}}
    !isfile(file_path) && throw(ArgumentError("File $file_path does not exist"))
    deserializer = LightOSM.file_deserializer(file_path)
    obj = deserializer(file_path)
    return composite_buildings_from_object(obj)
end


function composite_buildings_from_download(download_method::Symbol;
                                           metadata::Bool=false,
                                           download_format::Symbol=:osm,
                                           save_to_file_location::Union{String,Nothing}=nothing,
                                           download_kwargs...
                                           )::Dict{Integer, CompositeBuildings.AbstractBuilding{Integer}}
    obj = download_composite_osm_buildings(download_method;
                                           metadata=metadata,
                                           download_format=download_format,
                                           save_to_file_location=save_to_file_location,
                                           download_kwargs...)
    return composite_buildings_from_object(obj)
end