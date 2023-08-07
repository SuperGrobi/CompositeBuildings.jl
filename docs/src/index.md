```@meta
CurrentModule = CompositeBuildings
```

# CompositeBuildings

Documentation for [CompositeBuildings](https://github.com/SuperGrobi/CompositeBuildings.jl).

This package provides functions to load various datasets containing building data into consistents `DataFrames.DataFrame`s.

It as well provides the functionality to calculate shadows from these datasets.

# Interface
To properly work within the `MinistryOfCoolWalks` ecosystem, we expect the dataframes to follow a certain set of requirements:

1. Each row in the `DataFrame` represents a single building

1. Each `DataFrame` must have the following columns:
    - `:id` unique id of the building
    - `:height` height of building (m)
    - `:geometry` `ArchGDAL` polygon (single polygon, possibly with holes), with spatial reference applied.

1. The `DataFrame` must have `metadata` with a key of `observatory`, which contains a `CoolWalksUtils.ShadowObservatory`. This value contains the center coordinates used for projection to a local coordinate system and the timezone of the dataset, used to calculate the sunposition, for shadow projection.

The technical part of the last two of these requirements can be checked with [`CompositeBuildings.check_building_dataframe_integrity(df)`](@ref).

# API

```@index
Pages = ["index.md"]
```

```@autodocs
Modules = [CompositeBuildings]
Pages = ["CompositeBuildings.jl"]
```