function overpass_composite_building_query(download_method::Symbol, # this feels multiple dispatchy...
                                           boundary, 
                                           metadata::Bool=false, 
                                           download_format::Symbol=:osm)::String

    filters1 = """node["building"]({1});<;way["building"]({1});>;rel["building"]({1});>;"""
    filters2 = """node["building:part"]({1});<;way["building:part"]({1});>;rel["building:part"]({1});>;"""
    filters = "($filters1);($filters2);"
    full_filter_string = ""
    if download_method == :place_name
        geojson_polygons = LightOSM.polygon_from_place_name(boundary)
        for polygon in geojson_polygons
            polygon = map(x -> [x[2], x[1]], polygon) # switch lon-lat to lat-lon
            polygon_str = replace("$polygon", r"[\[,\]]" =>  "")
            full_filter_string *= format(filters, """poly:\"$polygon_str\"""")
        end
    elseif download_method == :bbox
        bbox_str =  """$(replace("$boundary", r"[\[ \]]" =>  ""))"""
        full_filter_string *= format(filters, bbox_str)
    elseif download_method == :point
        point, radius = boundary
        around_string = """around:$radius,$(point.lat), $(point.lon)"""
        full_filter_string *= format(filters, around_string)
    else
        throw(ErrorException("OSM composite building query builder can not generate a border of type $download_method"))
    end

    return LightOSM.overpass_query(full_filter_string, metadata, download_format)
end

function osm_composite_buildings_from_place_name(; place_name::String,
                                                metadata::Bool=false,
                                                download_format::Symbol=:osm)::String
    query = overpass_composite_building_query(:place_name, place_name, metadata, download_format)
    return LightOSM.overpass_request(query)
end

function osm_composite_buildings_from_bbox(; minlat::Float64,
                                           minlon::Float64,
                                           maxlat::Float64,
                                           maxlon::Float64,
                                           metadata::Bool=false,
                                           download_format::Symbol=:osm)::String
    bbox = [minlat, minlon, maxlat, maxlon]
    query = overpass_composite_building_query(:bbox, bbox, metadata, download_format)
    return LightOSM.overpass_request(query)
end

function osm_composite_buildings_from_point(; point::GeoLocation,
                                            radius::Number,
                                            metadata::Bool=false,
                                            download_format::Symbol=:osm)::String
    circle = (point, radius)
    query = overpass_composite_building_query(:point, circle, metadata, download_format)
    return LightOSM.overpass_request(query)
end

function osm_composite_buildings_downloader(download_method::Symbol)::Function
    if download_method == :place_name
        return osm_composite_buildings_from_place_name
    elseif download_method == :bbox
        return osm_composite_buildings_from_bbox
    elseif download_method == :point
        return osm_composite_buildings_from_point
    else
        throw(ErrorException("OSM composite buildings downloader $download_method does not exist"))
    end
end

function download_composite_osm_buildings(download_method::Symbol;
                                          metadata::Bool=false,
                                          download_format::Symbol=:osm,
                                          save_to_file_location::Union{String, Nothing}=nothing,
                                          download_kwargs...)::Union{XMLDocument, Dict{String,Any}}
    downloader = osm_composite_buildings_downloader(download_method)
    data = downloader(metadata=metadata, download_format=download_format; download_kwargs...)
    @info "Downloaded osm composite buildings data from $(["$k: $v" for (k, v) in download_kwargs]) in $download_format format"

    if !(save_to_file_location isa Nothing)
        save_to_file_location = LightOSM.validate_save_location(save_to_file_location, download_format)
        write(save_to_file_location, data)
        @info "Saved osm composite buildings data to disk: $save_to_file_location"
    end

    deserializer = LightOSM.string_deserializer(download_format)
    return deserializer(data)
end