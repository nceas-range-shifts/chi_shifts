here_aquax <- function(f = '', ...) {
  ### create file path to AquaX data dir for project
  f <- paste(f, ..., sep = '/')
  f <- stringr::str_replace_all(f, '\\/+', '/')
  f_anx <- sprintf('/home/shares/data-aquax/%s', f)
  return(f_anx)
}

get_aquax_meta <- function(meta = 'META_02122025.Rdata', sdm = TRUE) {
  load(here_aquax(meta))
  meta_clean <- META %>%
    janitor::clean_names()
  if(sdm) meta_clean <- meta_clean %>%
    filter(sdm == 'SDM')
  return(meta_clean)
}

get_spp_traits <- function() {
  ### run data mgmt scripts first!
  traits_dir <- here::here('data/spp_vuln_framework_traits')
  junction_df <- data.table::fread(file.path(traits_dir, 'spp_traits_junction.csv'))
  traitval_df <- data.table::fread(file.path(traits_dir, 'spp_traits_trait_val_lookup.csv'))
  taxa_df     <- data.table::fread(file.path(traits_dir, 'spp_traits_taxa_lookup.csv'))
  gapfill_df  <- data.table::fread(file.path(traits_dir, 'spp_traits_gapfill_levels.csv'))
  df <- junction_df %>%
    left_join(taxa_df, by = 'aphia_id') %>%
    left_join(traitval_df, by = 'trait_id') %>%
    left_join(gapfill_df, by = 'gf_match_id') %>%
    select(-trait_id, -gf_match_id)
  return(df)
}

get_spp_vuln <- function() {
  ### run data mgmt scripts first!
  vuln_dir <- here::here('data/spp_vuln_framework_scores')
  junction_df <- data.table::fread(file.path(vuln_dir, 'spp_vuln_junction.csv'))
  taxa_df     <- data.table::fread(file.path(vuln_dir, 'spp_vuln_taxa_lookup.csv'))
  stressor_df <- data.table::fread(file.path(vuln_dir, 'spp_vuln_stressor_lookup.csv'))
  df <- junction_df %>%
    left_join(taxa_df, by = 'aphia_id') %>%
    left_join(stressor_df, by = 'vuln_str_id') %>%
     select(-vuln_str_id)
  return(df)
}

get_sdm <- function(aphia_id, 
                    scenario = c('Current', 
                                 'RCP26_2050', 'RCP26_2100',
                                 'RCP45_2050', 'RCP45_2100', 
                                 'RCP85_2050', 'RCP85_2100'),
                    xrange = NULL, ### one or two numeric values
                    apply_thresh = TRUE) {
  ### SEE testing_methods_playground.qmd FOR OTHER VERSIONS
  ### Here going with duckdb version - slightly faster than dplyr
  ### version, plus memory benefit of not reading in then filtering
  
  ### define internal function:
  process_one_sdm <- function(id, scenario, apply_thresh) {
    filestem <- here_aquax('SDM/FINAL_EMSDM_EMMEAN_SP_%s.parquet')

    ### open connection, select/filter
    con <- duckdb::dbConnect(duckdb::duckdb())
    
    query_str <- paste0(
      "SELECT x, y, cutoff, ", paste(scenario, collapse = ', '),
      " FROM read_parquet('", sprintf(filestem, id), "')"
    )
    if(!is.null(xrange)) {
      ### tack on WHERE clause
      query_str <- paste0(
        query_str,
        " WHERE x <= ", max(xrange), " AND x >= ", min(xrange)
        )
    }
    df <- DBI::dbGetQuery(con, query_str) %>%
      janitor::clean_names() %>%
      mutate(aphia_id = id)
    
    ### close connection!
    duckdb::dbDisconnect(con, shutdown = TRUE)

    if(apply_thresh) {
      scen = tolower(scenario)
      df <- df %>%
        mutate(across(all_of(scen), ~ifelse(.x < cutoff, NA, 1))) %>%
        filter(!if_all(all_of(scen), is.na))
    }
    return(df)
  }
  ### if single ID, process directly; otherwise, parallel:
  if(length(aphia_id) == 1) {
    sdm_df <- process_one_sdm(id = aphia_id, 
                              scenario = scenario, 
                              apply_thresh = apply_thresh)
  } else {
    ### set # cores based on # ids, up to some max (20)
    n_cores <- min(length(aphia_id), 20)
    sdm_list <- parallel::mclapply(
      mc.cores = n_cores,
      X = aphia_id,
      FUN = process_one_sdm,
      scenario = scenario, apply_thresh = apply_thresh
    )
    sdm_df <- data.table::rbindlist(sdm_list)
  }
  return(sdm_df)
}
