Files in this directory are created by data_mgmt/4_data_access_iucn.qmd:

* iucn_marine_assessments.csv pulls assessment IDs (most recent) associated with  
  species flagged as "marine" system
* iucn_comp_group_assessments.csv pulls assessment IDs (most recent) associated  
  with comprehensively assessed groups containing marine species (and in many 
  cases containing non-marine species)
* iucn_species_assessments.csv contains IUCN sciname, assessment_id, 
  sis_taxon_id, redlist_version, redlist_category, assessed_year, scope
  
The iucn_species_assessments.csv are then combined with Aphia ID values from:

* AquaX metadata
* IUCN/WoRMS alignment from spp_vuln_framework

Species scinames not matched through these lists are then pinged to the WoRMS
API using the `taxize::classification` function.  Results are stored as:

* iucn_worms_check_pass1.csv

Finally, a set of IUCN scinames matched to WoRMS accepted names, including
IUCN sis_taxon_id, WoRMS aphia_id, and WoRMS valid_sciname are saved out:

* iucn_worms_aphia_id_complete.csv

