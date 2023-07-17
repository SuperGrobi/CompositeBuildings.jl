# CompositeBuildings

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://SuperGrobi.github.io/CompositeBuildings.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://SuperGrobi.github.io/CompositeBuildings.jl/dev/)
[![Build Status](https://github.com/SuperGrobi/CompositeBuildings.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/SuperGrobi/CompositeBuildings.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

Here I will do all the building related stuff of the CoolWalks project. The main functionality (currently...) is intended to do all kinds of preprocessing on osm and all the other building related data sources, to return unified data for later use in the evaluation pipeline.
(This is the place where I would put all the code to get building polygons and heights from DEM, LIDAR, 3D models and so on. (IF I HAD ANY!) (if I am ever going to write it...))

# Supported things
Currently, we can load:
- EMU analytics british building dataset
- New York City open data building dataset
- Spain cadastral building dataset (some preprocessing is needed, downloader utilities are included.)

## Metadata
the `DataFrames` returned by the loader functions have two metadata tags attached:

- :center_lon
- :center_lat

which hold the approximate center of the data in the dataframe, in WSG84 lon and lat respectively. (I say approximately, since I reuse these coordinates whenever possible. For example during shadow casting.)

## Disclaimer
I have no idea what I am doing. Stuff WILL break. Use with care. You have been warned.