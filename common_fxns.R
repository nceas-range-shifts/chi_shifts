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
  traits_dir <- here::here('_data_raw/ohara_2024/spp_vuln_framework_traits')
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
  vuln_dir <- here::here('_data_raw/ohara_2024/spp_vuln_framework_scores')
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
                    xrange = NULL,       ### one or two numeric values
                    apply_thresh = TRUE,
                    batch_size = 1000,   ### files per duckdb query - tune on server
                    threads = 60,        ### cap duckdb worker threads - shared server!
                    memory_limit = '300GB') { ### cap duckdb memory - shared server!
  filestem <- here_aquax('SDM/FINAL_EMSDM_EMMEAN_SP_%s.parquet')
  all_files <- sprintf(filestem, aphia_id)

  batches <- split(all_files, ceiling(seq_along(all_files) / batch_size))

  con <- duckdb::dbConnect(duckdb::duckdb())
  if(!is.null(threads)) {
    DBI::dbExecute(con, sprintf('SET threads=%d;', threads))
  }
  if(!is.null(memory_limit)) {
    DBI::dbExecute(con, sprintf("SET memory_limit='%s';", memory_limit))
  }
  on.exit(duckdb::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  process_batch <- function(files) {
    file_list_sql <- paste0("[", paste0("'", files, "'", collapse = ", "), "]")

    if(apply_thresh) {
      ### do the thresholding (and the "keep row if at least one scenario
      ### cleared its cutoff" filter) inside duckdb instead of R - lets
      ### duckdb's vectorized/columnar engine do this in place rather than
      ### materializing the untransformed data frame in R first.
      ### explicit IS NULL branch matters: SQL's CASE treats an unknown/NULL
      ### condition (`NULL < cutoff`) as non-matching and falls through to
      ### ELSE, silently turning missing raw values into 1. R's
      ### ifelse(NA < cutoff, NA, 1) correctly propagates NA instead.
      scen_exprs <- paste0(
        "CASE WHEN ", scenario, " IS NULL THEN NULL ",
        "WHEN ", scenario, " < cutoff THEN NULL ELSE 1 END AS ", tolower(scenario)
      )
      select_cols <- paste(scen_exprs, collapse = ', ')
      keep_clause <- paste0("(", paste(scenario, ">= cutoff", collapse = ' OR '), ")")
      query_str <- paste0(
        "SELECT ROUND(x, 3) AS x, ROUND(y, 3) AS y, cutoff, ", select_cols, ", ",
        "CAST(regexp_extract(filename, '_SP_([0-9]+)\\.parquet$', 1) AS INTEGER) AS aphia_id ",
        "FROM read_parquet(", file_list_sql, ", filename=true, union_by_name=true) ",
        "WHERE ", keep_clause
      )
    } else {
      select_cols <- paste(scenario, collapse = ', ')
      query_str <- paste0(
        "SELECT x, y, cutoff, ", select_cols, ", ",
        "CAST(regexp_extract(filename, '_SP_([0-9]+)\\.parquet$', 1) AS INTEGER) AS aphia_id ",
        "FROM read_parquet(", file_list_sql, ", filename=true, union_by_name=true)"
      )
    }
    if(!is.null(xrange)) {
      query_str <- paste0(
        query_str,
        if(apply_thresh) " AND x <= " else " WHERE x <= ", max(xrange), " AND x >= ", min(xrange)
      )
    }
    DBI::dbGetQuery(con, query_str)
  }

  df_list <- lapply(batches, process_batch)
  df <- collapse::rowbind(df_list) %>%
    janitor::clean_names()

  return(df)
}

sample_decomp <- function(df) {
  ### MAJOR REWRITE - full vectorization and use of
  ### collapse::fsum etc within group objects - drop the skew and kurtosis
  ### for speed and ease
  
  # df <- tx_tmp_dfs %>% fsubset(x < -170 & scenario == 'rcp45_2050')
  g <- GRP(df, ~ x + y + scenario)
  
  n     <- df$n
  mn    <- df$mean
  var_i <- df$sd^2
  
  ### broadcast pooled n and pooled mean back to row level (for deviations)
  pool_n_bc    <- fsum(n, g = g, TRA = "replace")
  pool_mean_bc <- fsum(n * mn, g = g, TRA = "replace") / pool_n_bc
  deviation    <- mn - pool_mean_bc
  
  SS <- (n - 1) * var_i
  SS[n == 1] <- 0
  
  ### group-level pooled n / mean / var / sd
  pool_n    <- fsum(n, g = g)
  pool_mean <- fsum(n * mn, g = g) / pool_n
  pool_dev_sum <- fsum(n * deviation^2, g = g)
  pool_SS   <- fsum(SS, g = g) + pool_dev_sum
  pool_var  <- pool_SS / (pool_n - 1)
  pool_sd   <- sqrt(pool_var)
  
  summary_df <- data.frame(
    x = g$groups$x,
    y = g$groups$y,
    n    = pool_n,
    mean = pool_mean,
    sd   = pool_sd,
    row.names = NULL
  )
  
  return(summary_df)
}
