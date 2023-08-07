function square(x, y, s)
    xs = [0.0, 1.0, 1.0, 0.0, 0.0] .* s .+ x
    ys = [0.0, 0.0, 1.0, 1.0, 0.0] .* s .+ y
    return collect(zip(xs, ys))
end

function collection(stuff)
    collection = ArchGDAL.creategeomcollection()
    for i in stuff
        ArchGDAL.addgeom!(collection, i)
    end
    return collection
end