using CompositeBuildings
using Documenter

DocMeta.setdocmeta!(CompositeBuildings, :DocTestSetup, :(using CompositeBuildings); recursive=true)

makedocs(;
    modules=[CompositeBuildings],
    authors="Henrik Wolf <henrik-wolf@freenet.de> and contributors",
    repo="https://github.com/SuperGrobi/CompositeBuildings.jl/blob/{commit}{path}#{line}",
    sitename="CompositeBuildings.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://SuperGrobi.github.io/CompositeBuildings.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Loading Data" => "OtherLoaders.md",
        "Shadow Casting" => "ShadowCasting.md"
    ],
)

deploydocs(;
    repo="github.com/SuperGrobi/CompositeBuildings.jl",
    devbranch="main",
)
