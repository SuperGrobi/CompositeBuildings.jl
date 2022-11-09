function bounding_box(geo_colunm)
    boxes = ArchGDAL.boundingbox.(geo_colunm)
    min_lat = Inf
    min_lon = Inf
    max_lat = -Inf
    max_lon = -Inf
    for box in boxes
        for point in GeoInterface.getpoint(box)
            lat = getcoord(point, 2)
            lon = getcoord(point, 1)
            min_lat > lat && (min_lat = lat)
            max_lat < lat && (max_lat = lat)
            min_lon > lon && (min_lon = lon)
            max_lon < lon && (max_lon = lon)
        end
    end
    box = createpolygon([(min_lon, min_lat), (min_lon, max_lat), (max_lon, max_lat), (max_lon, min_lat), (min_lon, min_lat)])
    apply_wsg_84!(box)
    return (minlat=min_lat, minlon=min_lon, maxlat=max_lat, maxlon=max_lon), box
end