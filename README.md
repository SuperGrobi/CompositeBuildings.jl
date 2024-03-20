# CompositeBuildings

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://SuperGrobi.github.io/CompositeBuildings.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://SuperGrobi.github.io/CompositeBuildings.jl/dev/)
[![Build Status](https://github.com/SuperGrobi/CompositeBuildings.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/SuperGrobi/CompositeBuildings.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

Building related code for the CoolWalks project. Mainly concerned with loading,
preprocessing and unifying various data sources for further use.

The shadow-casting code for buildings lives here as well.

# Supported datasets
- [EMU analytics british building dataset](https://www.emu-analytics.com/products/datapacks)
- [New York City open data building dataset](https://data.cityofnewyork.us/Housing-Development/Building-Footprints/nqwf-w8eh)
- [Spain cadastral building dataset](https://www.catastro.minhap.es/webinspire/index.html) (some preprocessing is needed, downloader utilities are included.)
