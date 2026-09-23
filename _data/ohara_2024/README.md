# `_data/ohara_2024/` — Species Vulnerability Traits and Functional Entity Traits

## Scripts
- `data_mgmt/data_access_vuln_traits.qmd` — downloads vulnerability framework traits and scores
- `data_mgmt/data_access_funct_entities.qmd` — assembles functional entity trait table

## Contents
- `spp_vuln_framework_traits/` — per-species vulnerability trait values (sensitivity, adaptive capacity dimensions)
- `spp_vuln_framework_scores/` — aggregated vulnerability scores per species and stressor
- `funct_entity_traits/` — combined trait table used to assign species to functional entities:
  - `fe_spp_traits.csv` — length, trophic level, mobility, water column position, age at maturity, fecundity per species (with AphiaID)

## Source / URL
Vulnerability traits and scores hosted at KNB:
https://knb.ecoinformatics.org/view/doi:10.5063/F1QC0211

- Traits zip: `https://knb.ecoinformatics.org/knb/d1/mn/v2/object/urn%3Auuid%3Ab04c2ef1-7e75-4cd7-977f-56710fc57a9c`
- Scores zip: `https://knb.ecoinformatics.org/knb/d1/mn/v2/object/urn%3Auuid%3A614cd599-78eb-4e6b-905e-e68a2b2a0489`

Functional entity traits sourced from GitHub:
https://github.com/mapping-marine-spp-vuln/spp_vuln_mapping/tree/main/_data/traits_grouping

Species name/AphiaID update table:
https://raw.githubusercontent.com/mapping-marine-spp-vuln/spp_vuln_framework/refs/heads/master/update/update_sciname_aphia.csv

## Citation
O'Hara, C. C., et al. (2024). Cumulative human impacts on global marine fauna highlight risk to biological and functional diversity. *PLOS ONE*, 19(9), e0309788. https://doi.org/10.1371/journal.pone.0309788

Butt, N., et al. (2022). A trait-based framework for assessing the vulnerability of marine species to human impacts. *Ecosphere*, 13(2), e3919. https://doi.org/10.1002/ecs2.3919
