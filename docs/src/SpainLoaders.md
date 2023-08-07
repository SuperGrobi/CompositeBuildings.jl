# Spain Building Loaders and Utilities
## Introduction
Spain provides easy access to their cadastral dataset of building footprints and metadata. We provide some functions to inspect, download, preprocess and load the available data.

The returned `DataFrames` conform to the requirements needed to be a source for building data.

## Usage example

## API
```@index
Pages = ["SpainLoaders.md"]
```

### Inspect datasets
```@meta
CurrentModule = CompositeBuildings
```

```@docs
parse_polygon_string
parse_spain_xml
download_spain_overview
download_spain_region_overview
```

 ### Download and process
```@docs
download_spain_subregion
load_spain_buildings_gml
load_spain_parts_gml
relate_floors
preprocess_spain_subregion
```
 ### Load
 ```@docs
load_spain_processed_buildings
```