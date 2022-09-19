"""
constructs a dataframe which contains two id columns, describing the relation between two dataframes.
Both dataframes are expected to have at least an :id and an :geometry column.
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
    for r1 in eachrow(df1)
        for r2 in eachrow(df2)
            area_intersection = GeoInterface.area(GeoInterface.intersection(r1.geometry, r2.geometry))
            area_minimum = min(GeoInterface.area(r1.geometry), GeoInterface.area(r2.geometry))
            if area_intersection >= area_minimum * overlap
                push!(df, [r1.id, r2.id])
            end
        end
    end
    return df
end