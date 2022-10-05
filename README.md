# CompositeBuildings
Here I will do all the building related stuff of the CoolWalks project. The main functionality (currently...) is intended to do all kinds of preprocessing on osm and all the other building related data sources, to return unified data for later use in the evaluation pipeline.
(This is the place where I would put all the code to get building polygons and heights from DEM, LIDAR, 3D models and so on. (IF I HAD ANY!) (if I am ever going to write it...))

currently, there are two sources supported:
- OSM
- EmuAnalytics British Cities Dataset

For the OSM functions we have:
- `osm_dfs_from_object`
- `osm_dfs_from_file`
- `osm_dfs_from_download`
these functions work like their counterparts in `LightOSM.jl` with the exception, that they not only get all things which are taged as `building=*` but also the things with a `building:part=*` tag. They return a tuple of `DataFrame`s, the first one containing the data for buildings, the second one containing the data for parts.
Both of these dataframes are guaranteed to have a `:geometry` and a `:id` column. The first contains a valid (in terms of the Simple Feature Access standard (with a few exceptions. (I believe))) (if the `return_invalid` keyword is set to false) ArchGDAL Polygon describing the building/part footprint, the second one contains the osm id of the way/relation the building/part was taken from.

For the EMU function we have:
- `load_british_shapefiles(path; bbox=(minlat=0, minlon=0, maxlat=0, maxlon=0)`
Which loads the shapefile at path and, if wanted, crops it to only the things within the bounding box (assuming WSG84 coordinates)
The returned `DataFrame` is guaranteed to have the same two columns as the OSM one.

All ArchGDAL polygons have the WSG84 coordinate System applied.

this package also provides the `relate_buildings` function, used find related building in two `DataFrame`s. (Introducing the first arbitrary parameter)


Disclaimer: I have no idea what I am doing. Stuff WILL break. Use with care. You have been warned.