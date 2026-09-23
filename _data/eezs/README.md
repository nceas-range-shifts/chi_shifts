# `_data/eezs/` — EEZ and Georegion Data

## Script
`data_mgmt/data_access_eezs.qmd`

## Contents
- `un_m49_codes.tif` — global 0.05° raster of UN M49 country/territory codes, rasterized from EEZ polygons
- `UNSD — Methodology.csv` — UN M49 georegion lookup table (region, sub-region, intermediate region codes and names); downloaded from https://unstats.un.org/unsd/methodology/m49/overview/
- `esri_world_continents.gpkg` — ESRI World Continents polygon layer; downloaded from https://hub.arcgis.com/datasets/esri::world-continents/explore 2026-08-06

## Source / URL
- EEZ polygons: Marine Regions, World EEZ v12 (2023-10-25)
  - Attribute table: https://www.marineregions.org/eezattribute.php
  - Stored on shared server at `/home/shares/usgs-cap-rangeshifts/spatial/World_EEZ_v12_20231025_gpkg/eez_v12.gpkg` (read-only)
- UN M49 codes: https://unstats.un.org/unsd/methodology/m49/overview/

## Citation
Flanders Marine Institute (2023). Maritime Boundaries Geodatabase: Maritime Boundaries and Exclusive Economic Zones (200NM), version 12. Available online at https://www.marineregions.org/. https://doi.org/10.14284/632

