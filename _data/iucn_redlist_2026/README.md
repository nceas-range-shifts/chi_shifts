# `_data/iucn_redlist_2026/` — IUCN Red List Assessments and WoRMS Crosswalks

## Script
`data_mgmt/data_access_iucn.qmd`

## Contents
- `iucn_species_assessments.csv` — IUCN sciname, assessment_id, sis_taxon_id, redlist_version, redlist_category, assessed_year, scope for all marine and comprehensively assessed species
- `iucn_worms_aphia_id_complete.csv` — final crosswalk: IUCN sciname → WoRMS valid name + AphiaID, with AquaX SDM status
- `int/` — intermediate files:
  - `iucn_marine_assessments.csv` — assessment IDs for species flagged as marine system
  - `iucn_comp_group_assessments.csv` — assessment IDs for comprehensively assessed groups
  - `iucn_worms_check_pass1.csv` — WoRMS API lookup results for unmatched names (via `taxize`)
  - `worms_aphia_to_iucn_sis.csv` — WoRMS external ID endpoint results (Aphia → SIS)
  - `worms_synonyms.csv` — WoRMS synonym lookup results
  - `aquax_iucn_manual.csv` — manually resolved AquaX species with no automatic IUCN match

## Source / URL
- IUCN Red List API: requires API key set as `IUCN_API_KEY` in `.Renviron`
  - R package: `iucnredlist` (https://github.com/IUCN-UK/iucnredlist)
- WoRMS API (via `taxize` and direct REST calls): https://www.marinespecies.org/rest/
- Species name/AphiaID update table: https://raw.githubusercontent.com/mapping-marine-spp-vuln/spp_vuln_framework/refs/heads/master/update/update_sciname_aphia.csv

## Citation
IUCN (2026). The IUCN Red List of Threatened Species. Version 2026. https://www.iucnredlist.org

WoRMS Editorial Board (2026). World Register of Marine Species. Available from https://www.marinespecies.org at VLIZ. https://doi.org/10.14284/170

