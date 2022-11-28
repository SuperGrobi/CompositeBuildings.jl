"""

    relate_buildings(df1, df2, id1= :id_1, id2= :id_2; overlap=0.7)

constructs a dataframe with two id columns, relating geometries from `df1` and `df2` which overlap at least `overlap`.
Both dataframes are expected to have at least an :id and an :geometry column.

By setting `id1` and `id2`, you can decide the names of the resulting columns for the two dataframes, respectively.

Two geometries g1, g2 are related, if:
area(intersection(g1, g2)) >= min(area(g1), area(g2)) * overlap
"""
function relate_buildings(df1, df2, id1= :id_1, id2= :id_2; overlap=0.7)
    cols = Dict(
        id1 => typeof(df1.id)(),
        id2 => typeof(df2.id)()
    )
    df = DataFrame(cols...)
    # This could probably be way faster, if we sort our rows in some sort of binary spatial partition tree...
    # this will probably also help later, for figuring out if some point is in the shadow of a building or not.
    @showprogress 1 "building relation table" for r1 in eachrow(df1)
        for r2 in eachrow(df2)
            GeoInterface.disjoint(r1.geometry, r2.geometry) && continue  # 4 times speedup...
            area_intersection = GeoInterface.area(GeoInterface.intersection(r1.geometry, r2.geometry))
            area_minimum = min(GeoInterface.area(r1.geometry), GeoInterface.area(r2.geometry))
            if area_intersection >= area_minimum * overlap
                push!(df, [r1.id, r2.id])
            end
        end
    end
    return df
end
