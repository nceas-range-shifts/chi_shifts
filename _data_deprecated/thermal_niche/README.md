### Thermal niche data from AquaX

The .parquet file here is assembled from species-specific .Rdata files from AquaX.  See the `data_access_aquax_thermal_niche.qmd` script for processing details.

For each species, thermal niche data are provided for pelagic (surface) and benthic (seafloor), for bin (modeled) and occ (observations).

Data values accord with BioORACLE: thetao_min. thetao_ltmin, thetao_mean, thetao_max, thetao_ltmax, thetao_range.  The data in this file are rounded to four decimal places because really, come on.

###############################
### Full README from AquaX: ###
###############################

THERMAL NICHE OUTPUTS (BIN/OCC x Surface/Seafloor)
﻿
Location
- Root: ANALYSIS/THERMAL_NICHE_MARINE_SPECIES
- Main niche outputs: ANALYSIS/THERMAL_NICHE_MARINE_SPECIES/data_export
﻿
Four niche folders (Rdata only)
1) NICHE_PELAGIC_BIN
   - BIN-derived niche statistics extracted from SURFACE temperature raster
2) NICHE_PELAGIC_OCC
   - OCC-derived niche statistics extracted from SURFACE temperature raster
3) NICHE_SEAFLOOR_BIN
   - BIN-derived niche statistics extracted from SEAFLOOR (depthmean) temperature raster
4) NICHE_SEAFLOOR_OCC
   - OCC-derived niche statistics extracted from SEAFLOOR (depthmean) temperature raster
﻿
File naming convention
- Surface BIN:
  NICHE_MOD_SP_<AphiaID>_PELAGIC_BIN_NOOUTLIERS_ALLTEMP.Rdata
- Surface OCC:
  NICHE_MOD_SP_<AphiaID>_PELAGIC_OCC_FLAG1_NOOUTLIERS_ALLTEMP.Rdata
- Seafloor BIN:
  NICHE_MOD_SP_<AphiaID>_SEAFLOOR_BIN_NOOUTLIERS_ALLTEMP.Rdata
- Seafloor OCC:
  NICHE_MOD_SP_<AphiaID>_SEAFLOOR_OCC_FLAG1_NOOUTLIERS_ALLTEMP.Rdata
﻿
Notes on naming
- FLAG1 (OCC): only occurrence records with flag==1 are used (GOODOCC when available; fallback to original_flags or flag).
- NOOUTLIERS: IQR filtering is applied per variable before computing summary stats.
- ALLTEMP: all 6 temperature variables are included.
﻿
Species and layer selection rules (from META)
- Species are processed only if both:
  - bin_file_found == 1
  - occ_file_found == 1
- Surface niche is computed when Pelagic==1 OR Demersal==1 OR Benthic==1.
- Seafloor niche is computed when Demersal==1 OR Benthic==1.
﻿
What each .Rdata contains
- Object name: df_stats
- Typical ALLTEMP format: 6 rows x 13 columns
  - Rows (variable):
    thetao_min, thetao_ltmin, thetao_mean, thetao_max, thetao_ltmax, thetao_range
  - Columns:
    mean, min, max, q01, q025, q05, q25, q50, q75, q95, q975, q99, variable
﻿
Breadth metrics note
- Breadth metrics are computed downstream from thetao_mean percentiles:
  - Breadthq95_5 = q95(thetao_mean) - q05(thetao_mean)
  - Breadthq975_025 = q975(thetao_mean) - q025(thetao_mean)
- These are used in derived analysis/map products under data_export, but are not stored as extra rows/columns in the standard NICHE_*_ALLTEMP per-species files.
﻿
Legacy exception
- A few early files (example AphiaID 835170 without "_ALLTEMP") contain only:
  - variables: thetao_mean, thetao_range
  - columns: mean, min, max, q01, q05, q25, q50, q75, q95, q99, variable
﻿
How statistics are computed
For each species, source (BIN or OCC), layer (surface or seafloor), and variable:
1) Match species presence locations to raster pixels.
2) Keep finite values only.
3) Remove outliers with IQR rule:
   - lower = Q1 - 1.5*IQR
   - upper = Q3 + 1.5*IQR
4) Compute:
   - mean, min, max
   - percentiles: 1, 2.5, 5, 25, 50, 75, 95, 97.5, 99
﻿
Input filtering details
- BIN presence: cells where Current_NR (or Current) != 0.
- OCC presence: records with finite longitude/latitude and occurrence flag == 1.
﻿
Bio-ORACLE variable meaning (temperature)
The thetao variables represent sea water potential temperature.
- thetao_mean: mean temperature
- thetao_min: minimum temperature
- thetao_max: maximum temperature
- thetao_ltmin: long-term minimum temperature
- thetao_ltmax: long-term maximum temperature
- thetao_range: thermal range (documented as max - min; temperature usage notes describe it as the average absolute max-min difference)
﻿
Depth interpretation: surface vs seafloor (depthmean)
- Surface raster in this workflow:
  Temperature_BIOORACLEV3_baseline_allvar_surface_2000_2010.tif
  Uses Bio-ORACLE "surface" conditions (depthsurf).
  Documentation indicates depthsurf corresponds to the upper ocean layer (0 to 0.49 m).
﻿
- Seafloor raster in this workflow:
  Temperature_BIOORACLEV3_baseline_allvar_depthmean_2000_2010.tif
  Uses Bio-ORACLE benthic depthmean conditions.
  depthmean means environmental data extracted at the average bathymetric depth of each focal grid cell (0.05 degree), not a single fixed depth everywhere.
  In steep-slope cells, this is an interpolated representation of benthic conditions.
﻿
Quick load example in R
- load("NICHE_MOD_SP_<AphiaID>_PELAGIC_BIN_NOOUTLIERS_ALLTEMP.Rdata")
- str(df_stats)
﻿
Documentation references used
- Bio-ORACLE v3 summary and usage notes:
  https://www.bio-oracle.org/documentation.php
- Bio-ORACLE FAQ (depthsurf/depthmean and benthic extraction details):
  https://www.bio-oracle.org/faq.php
- Variable metadata (thetao = sea water potential temperature):
  https://erddap.bio-oracle.org/erddap/info/BioORACLEv3_0_depthmean/index.html
  https://erddap.bio-oracle.org/erddap/info/BioORACLEv3_0_depthsurf/index.html
﻿
Prepared on: 2026-03-10
The Aquamaps 2.0 team 
﻿
For more questions: email: Gabriel.reygondeau@miami.edu
