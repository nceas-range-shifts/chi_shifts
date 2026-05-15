here_aquax <- function(f = '', ...) {
  ### create file path to AquaX data dir for project
  f <- paste(f, ..., sep = '/')
  f <- stringr::str_replace_all(f, '\\/+', '/')
  f_anx <- sprintf('/home/shares/data-aquax/%s', f)
  return(f_anx)
}

get_spp_traits <- function() {
  junction_f  <- here::here('data/spp_vuln_framework_traits/spp_traits_junction.csv')
  taxa_f      <- here::here('data/spp_vuln_framework_traits/spp_traits_taxa_lookup.csv')
  trait_val_f <- here::here('data/spp_vuln_framework_traits/spp_traits_trait_val_lookup.csv')
  gapfill_f   <- here::here('data/spp_vuln_framework_traits/spp_traits_gapfill_levels.csv')
  
  junction_df  <- data.table::fread(junction_f)
  taxa_df      <- data.table::fread(taxa_f)
  trait_val_df <- data.table::fread(trait_val_f)
  gapfill_df   <- data.table::fread(gapfill_f)
  
  spp_traits_df <-  junction_df %>%
    dplyr::left_join(taxa_df, by = 'gf_spp_id') %>%
    dplyr::left_join(trait_val_df, by = 'gf_trait_id') %>%
    dplyr::left_join(gapfill_df, by = 'gf_match_id') %>%
    ### drop id columns:
    dplyr::select(-ends_with('_id'))
  
  return(spp_traits_df)
}