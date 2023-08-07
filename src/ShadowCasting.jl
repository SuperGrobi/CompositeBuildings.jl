"""
Sometimes, due to numerical errors, the resulting shadows are no longer of `polygon` type, but might contain
some (usually very short) lines or points. This function removes these artefacts and returns only the `polygon`
contained in the `shadow`.

    shadow_cleanup(shadow)

entry function for cleanup. dispatches on `geomtrait` of `shadow.`

    shadow_cleanup(::PolygonTrait, shadow)

returns `shadow` as it is.

    shadow_cleanup(::GeometryCollectionTrait, shadow)

returns the `polygon` in the `shadow`. If there is more than on polygon, or if there is at least one `multi polygon`
it throws an `ArgumentError`.
"""
shadow_cleanup(shadow) = shadow_cleanup(geomtrait(shadow), shadow)
shadow_cleanup(::PolygonTrait, shadow) = shadow
function shadow_cleanup(::GeometryCollectionTrait, shadow)
    polygons = filter(x -> geomtrait(x) isa PolygonTrait, collect(getgeom(shadow)))
    multi_polygons = filter(x -> geomtrait(x) isa MultiPolygonTrait, collect(getgeom(shadow)))
    if length(polygons) == 1 && length(multi_polygons) == 0
        return first(polygons)
    else
        throw(ArgumentError("the resulting geometry $shadow has more than one polygon $polygons or at least one multipoligon $multi_polygons"))
    end
end

"""
    cast_shadows(buildings_df, time::DateTime)
    cast_shadows(buildings_df, sun_direction::AbstractVector)
    
creates new `DataFrame` with the shadows of the buildings in `buildings_df`.

# arguments
- `buildings_df`: DataFrame with metadata of `observatory`. Is assumend to fulfill the requirements for a building source.
- `time`: Local `DateTime` for which the shadows shall be calculated. Or:
- `sun_direction`: unit vector pointing towards the sun in local coordinates (x east, y north, z up)

# returns
`DataFrame` with columns
- `id`: id of building
- `geometry`: `ArchGDAL` polygon representing shadow of building with `id` in global coordinates

and the same metadata as `buildings_df`.
"""
cast_shadows(buildings_df, time::DateTime) = cast_shadows(buildings_df, local_sunpos(time, metadata(buildings_df, "observatory")))
function cast_shadows(buildings_df, sun_direction::AbstractVector)
    @assert sun_direction[3] > 0 "the sun is below or on the horizon. Everything is in shadow."
    #@info "this function assumes you geometry beeing in a suitable crs to do projections"

    project_local!(buildings_df)

    shadow_df = DataFrame(geometry=typeof(buildings_df.geometry)(), id=typeof(buildings_df.id)())


    # find offset vector
    offset_vector = -sun_direction[1:2] ./ sun_direction[3]
    orthogonal_vector = [-offset_vector[2], offset_vector[1]]

    shadows_array = Vector{ArchGDAL.IGeometry{ArchGDAL.wkbPolygon}}(undef, nrow(buildings_df))

    pbar = ProgressBar(eachrow(buildings_df), printing_delay=1.0)
    set_description(pbar, "calucating building shadows")

    Threads.@threads for row in pbar
        points = GeoInterface.coordinates(GeoInterface.getexterior(row.geometry))
        height = row.height

        full_shadow = if is_convex(points)
            extrude_simple(points, offset_vector * height, orthogonal_vector)
        else
            cast_shadow_explicit(points, offset_vector * height)
        end

        shadows_array[rownumber(row)] = full_shadow
    end

    reinterp_crs!(shadows_array, ArchGDAL.getspatialref(buildings_df.geometry[1]))

    shadow_df = DataFrame(id=buildings_df.id, geometry=shadows_array)

    for key in metadatakeys(buildings_df)
        metadata!(shadow_df, key, metadata(buildings_df, key); style=:note)
    end

    project_back!(buildings_df.geometry)
    project_back!(shadow_df.geometry)
    return shadow_df
end

"""
    cast_shadow_explicit(points, offset_vector)

Takes a vector of points describing a polygon and calculates the shadow (pushing each point along `offset_vector`),
by explicitly constructing the rectangles and using `ArchGDAL` to get the unions. Exact for all polygons, but fairly slow.
"""
function cast_shadow_explicit(points, offset_vector)
    # build and unionise outer polygons
    outer_shadow = ArchGDAL.createpolygon()
    for i in 1:length(points)-1
        pl1 = points[i]
        pu1 = points[i] + offset_vector
        pl2 = points[i+1]
        pu2 = points[i+1] + offset_vector
        # buffer to prevent numerical problems when taking union of two polygons sharing only an edge
        # comes at the cost of twice the polycount in the final shadow
        outer_poly = ArchGDAL.buffer(ArchGDAL.createpolygon([pl1, pl2, pu2, pu1, pl1]), 0.001, 1)
        outer_shadow = ArchGDAL.union(outer_shadow, outer_poly)
    end
    holeless_lower_poly = ArchGDAL.createpolygon(points)

    return shadow_cleanup(ArchGDAL.union(outer_shadow, holeless_lower_poly))
end

"""
    extrude_simple(points, offset_vector, orthogonal_vector)

Takes a vector of points describing a polygon and calculates the shadow (pushing each point along `offset_vector`),
by fiddling around with the coordinates of the points. Works only for convex polygons, but is quite fast.
"""
function extrude_simple(points, offset_vector, orthogonal_vector)
    points = hcat(points...)
    proj_orv = @view(points[:, 1:end-1])' * orthogonal_vector
    n_points = length(proj_orv)
    max_ind = argmax(proj_orv)
    min_ind = argmin(proj_orv)

    max_ind_right = mod1(max_ind + 1, n_points)
    max_ind_left = mod1(max_ind - 1, n_points)

    # find the index, where the angle between offset_vector and outgoing edge is smaller.
    # that is the direction of the upper indices...
    r_max = points[:, max_ind_right] - points[:, max_ind]
    r_min = points[:, max_ind_left] - points[:, max_ind]
    max_right = normalize(r_max)' * offset_vector
    max_left = normalize(r_min)' * offset_vector

    direction = max_left > max_right ? 1 : -1

    natural_direction = sign(min_ind - max_ind)


    if natural_direction == direction
        lower_indices = max_ind:direction:min_ind
    else
        lower_indices = mod1.(max_ind:direction:min_ind+direction*length(proj_orv), length(proj_orv))
    end

    if natural_direction == direction
        upper_indices = mod1.(min_ind:direction:max_ind+direction*length(proj_orv), length(proj_orv))
    else
        upper_indices = min_ind:direction:max_ind
    end

    points = points[:, [lower_indices; upper_indices; [lower_indices[1]]]]
    nlp = length(lower_indices)
    for i in 1:length(upper_indices)
        points[1, i+nlp] += offset_vector[1]
        points[2, i+nlp] += offset_vector[2]
    end
    try
        return ArchGDAL.createpolygon(points[1, :], points[2, :])
    catch
        @warn points
    end
end