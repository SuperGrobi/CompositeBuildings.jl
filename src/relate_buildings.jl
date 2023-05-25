"""

    relate_buildings(df1, df2, id1= :id_1, id2= :id_2; overlap=0.7)

constructs a dataframe with two id columns, relating geometries from `df1` and `df2` which overlap at least `overlap`.
Both dataframes are expected to have at least an :id and an :geometry column. `df2` will be converted into an RTree.
Not sure what the implications of this are... The function might be faster if the longer dataframe is turned into the Tree.

By setting `id1` and `id2`, you can decide the names of the resulting columns for the two dataframes, respectively.

Two geometries g1, g2 are related, if:
area(intersection(g1, g2)) >= min(area(g1), area(g2)) * overlap
"""
function relate_buildings(df1, df2, id1=:id_1, id2=:id_2; overlap=0.7)
    cols = Dict(
        id1 => typeof(df1.id)(),
        id2 => typeof(df2.id)()
    )
    df = DataFrame(cols...)

    df2_tree = build_rtree(df2)

    # This could probably be way faster, if we sort our rows in some sort of binary spatial partition tree...
    # this will probably also help later, for figuring out if some point is in the shadow of a building or not.
    @showprogress 1 "building relation table" for r1 in eachrow(df1)
        for inter in intersects_with(df2_tree, rect_from_geom(r1.geometry))
            if ArchGDAL.intersects(inter.val.prep, r1.geometry)
                area_intersection = GeoInterface.area(GeoInterface.intersection(r1.geometry, inter.val.orig))
                area_minimum = min(GeoInterface.area(r1.geometry), GeoInterface.area(inter.val.orig))
                if area_intersection >= area_minimum * overlap
                    push!(df, [r1.id, inter.val.row.id])
                end
            end
        end
    end
    return df
end
