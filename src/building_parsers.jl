is_building_part(tags::Dict)::Bool = haskey(tags, "building:part")

function composite_height(tags::Dict)::Tuple{Union{Number, Missing}, Union{Number, Missing}}
    height = get(tags, "height", missing)
    levels = get(tags, "building:levels", missing) !== missing ? tags["building:levels"] : get(tags, "level", missing)
    roof_levels = get(tags, "roof:levels", missing)
    if !(height isa Missing)
        height = height isa String ? max([LightOSM.remove_non_numeric(h) for h in split(height, r"[+^;,-]")]...) : height
    end
    if !(levels isa Missing)
        levels = levels isa String ? round(max([LightOSM.remove_non_numeric(l) for l in split(levels, r"[+^;,-]")]...)) : levels
        levels = levels == 0 ? missing : levels
        # set building height to missing if there is no data.
        levels = missing  # rand(1:DEFAULT_MAX_BUILDING_LEVELS[])
    end
    if !(roof_levels isa Missing)
        roof_levels = roof_levels isa String ? round(max([LightOSM.remove_non_numeric(l) for l in split(roof_levels, r"[+^;,-]")]...)) : roof_levels
    end

    # ignore if there is no roof level, it is rarely used
    return height, roof_levels isa Missing ? levels : levels + roof_levels
end

const BuildingDict = Dict{Integer, CompositeBuildings.AbstractBuilding}

# it is, for some reason, impossible to define this as a constant...
OSM_ref() = ArchGDAL.importEPSG(4326) # TODO: figure out the correct order.
empty_poly() = ArchGDAL.createpolygon()

function apply_wsg_84!(geom)
    ArchGDAL.createcoordtrans(OSM_ref(), OSM_ref()) do trans
        ArchGDAL.transform!(geom, trans)
    end
end

function add_way_to_poly!(poly, way, nodes)
    nds = [nodes[n] for n in way["nodes"]]
    node_tuples = [(i.location.lon, i.location.lat) for i in nds]
    
    linear_ring = ArchGDAL.createlinearring(node_tuples)
    apply_wsg_84!(linear_ring)
    ArchGDAL.addgeom!(poly, linear_ring)
end


function parse_osm_composite_buildings_dict(osm_buildings_dict::AbstractDict)#::Dict{Integer, CompositeBuildings.AbstractBuilding}
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

    for relation in osm_buildings_dict["relation"]
        # parse all buildings with multiple rings
        if haskey(relation, "tags") && LightOSM.is_building(relation["tags"])
            tags = relation["tags"]
            rel_id = relation["id"]
            members = relation["members"]
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
            @assert ArchGDAL.isvalid(polygon) "polygon of relation building $rel_id is not valid!"
            buildings[rel_id] = SimpleBuilding{T}(rel_id, polygon, tags)

        # parse all multipolygon parts
        elseif haskey(relation, "tags") && is_building_part(relation["tags"])
            tags = relation["tags"]
            rel_id = relation["id"]
            members = relation["members"]
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
            @assert ArchGDAL.isvalid(polygon) "polygon of relation part $rel_id is not valid!"
            building_parts[rel_id] = BuildingPart{T}(rel_id, polygon, tags)
            # TODO: maybe refactor this whole thing into a function?
        end
    end

    for (way_id, way) in ways
        if haskey(way, "tags") && LightOSM.is_building(way["tags"]) && !(way_id in added_ways)
            tags = way["tags"]
            height, levels = composite_height(tags)
            tags["height"] = height
            tags["levels"] = levels

            polygon = empty_poly()
            add_way_to_poly!(polygon, way, nodes)
            apply_wsg_84!(polygon)
            @assert ArchGDAL.isvalid(polygon) "polygon of building $way_id is not valid!"
            buildings[way_id] = SimpleBuilding{T}(way_id, polygon, tags)

        elseif haskey(way, "tags") && is_building_part(way["tags"]) && !(way_id in added_ways)
            tags = way["tags"]
            # TODO: make sure all relevant tags are present
            # tags["height"] = composite_height(tags)

            polygon = empty_poly()
            add_way_to_poly!(polygon, way, nodes)
            apply_wsg_84!(polygon)
            @assert ArchGDAL.isvalid(polygon) "polygon of part $way_id is not valid!"
            building_parts[way_id] = BuildingPart{T}(way_id, polygon, tags)
        end
    end


    println("number of ways: ", length(ways))
    println("number of added ways: ", length(added_ways))
    println("numer of complex buildings: ", length(buildings))
    println("number of building parts: ", length(building_parts))
    # we have now parse all building outlines to buildings and all building Parts
    # now we have to associate building parts with the corresponding buildings
    # we do this by
    return buildings, building_parts
end

function composite_buildings_from_object(composite_xml_object::XMLDocument)#::Dict{Integer, CompositeBuildings.AbstractBuilding{Integer}}
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
                                           )#::Dict{Integer, CompositeBuildings.AbstractBuilding{Integer}}
    obj = download_composite_osm_buildings(download_method;
                                           metadata=metadata,
                                           download_format=download_format,
                                           save_to_file_location=save_to_file_location,
                                           download_kwargs...)
    return composite_buildings_from_object(obj)
end

buildings_from_test_area() = composite_buildings_from_download(:bbox; minlat=55.6830369, minlon=12.5905037, maxlat=55.687142, maxlon=12.596064)