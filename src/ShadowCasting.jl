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
returns 
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
    cast_shadow(buildings_df, height_key, sun_direction::AbstractArray)

creates new `DataFrame` with the shadows of the buildings in `buildings_df` with the height given in the column with `height_key`.

# arguments
- `buildings_df`: DataFrame with metadata of `center_lat` and `center_lon` and at least these columns:
    - `geometry`: `ArchGDAL` polygon in wsg84 crs (use `apply_wsg_84!` from `CoolWalksUtils.jl`)
    - `id`: unique id for each building.
    - height_key: column with name given in parameter `height_key`, containing the heights of the buildings.
- `height_key`: name of column containing the height of the buildings
- `sun_direction`: direction of sun
"""
function cast_shadow(buildings_df, height_key, sun_direction::AbstractArray)
    @assert sun_direction[3] > 0 "the sun is below or on the horizon. Everything is in shadow."
    #@info "this function assumes you geometry beeing in a suitable crs to do projections"

    project_local!(buildings_df.geometry, metadata(buildings_df, "center_lon"), metadata(buildings_df, "center_lat"))

    shadow_df = DataFrame(geometry=typeof(buildings_df.geometry)(), id=typeof(buildings_df.id)())

    for key in metadatakeys(buildings_df)
        metadata!(shadow_df, key, metadata(buildings_df, key); style=:note)
    end

    # find offset vector
    offset_vector = -sun_direction[1:2] ./ sun_direction[3]
    orthogonal_vector = [-offset_vector[2], offset_vector[1]]

    @showprogress 1 "calculating shadows" for row in eachrow(buildings_df)
        points = to_points(row.geometry)
        height = getproperty(row, height_key)
        full_shadow = if is_convex(points)
            extrude_simple(points, offset_vector * height, orthogonal_vector)
        else
            cast_shadow_explicit(points, offset_vector * height)
        end
        reinterp_crs!(full_shadow, ArchGDAL.getspatialref(row.geometry))
        push!(shadow_df, [full_shadow, row.id])
    end
    project_back!(buildings_df.geometry)
    project_back!(shadow_df.geometry)

    return shadow_df
end

function cast_shadow_explicit(points, offset_vector)
    # build and unionise outer polygons
    outer_shadow = ArchGDAL.createpolygon()
    for i in 1:size(points, 2)-1
        pl1 = points[:, i]
        pu1 = points[:, i] + offset_vector
        pl2 = points[:, i+1]
        pu2 = points[:, i+1] + offset_vector
        # buffer to prevent numerical problems when taking union of two polygons sharing only an edge
        # comes at the cost of twice the polycount in the final shadow
        outer_poly = ArchGDAL.buffer(ArchGDAL.createpolygon([pl1, pl2, pu2, pu1, pl1]), 0.001, 1)
        outer_shadow = ArchGDAL.union(outer_shadow, outer_poly)
    end
    holeless_lower_poly = ArchGDAL.createpolygon(points[1, :], points[2, :])

    return shadow_cleanup(ArchGDAL.union(outer_shadow, holeless_lower_poly))
end

function extrude_simple(points, offset_vector, orthogonal_vector)
    proj_orv = @view(points[:, 1:end-1])' * orthogonal_vector
    n_points = length(proj_orv)
    max_ind = argmax(proj_orv)
    min_ind = argmin(proj_orv)

    max_ind_right = mod1(max_ind + 1, n_points)
    max_ind_left = mod1(max_ind - 1, n_points)

    max_right = (points[:, max_ind_right])' * offset_vector
    max_left = (points[:, max_ind_left])' * offset_vector

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

    return ArchGDAL.createpolygon(points[1, :], points[2, :])
end

function to_points(geom)
    lower_ring = getgeom(geom, 1)
    return hcat((collect(getcoord(x)) for x in getgeom(lower_ring))...)
end

CoolWalksUtils.is_convex(geom::ArchGDAL.IGeometry) = geom |> to_points |> is_convex