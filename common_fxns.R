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
  traits_dir <- here::here('_data/ohara_2024/spp_vuln_framework_traits')
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
  vuln_dir <- here::here('_data/ohara_2024/spp_vuln_framework_scores')
  junction_df <- data.table::fread(file.path(vuln_dir, 'spp_vuln_junction.csv'))
  taxa_df     <- data.table::fread(file.path(vuln_dir, 'spp_vuln_taxa_lookup.csv'))
  stressor_df <- data.table::fread(file.path(vuln_dir, 'spp_vuln_stressor_lookup.csv'))
  df <- junction_df %>%
    left_join(taxa_df, by = 'aphia_id') %>%
    left_join(stressor_df, by = 'vuln_str_id') %>%
     select(-vuln_str_id)
  return(df)
}

calc_cellrange <- function(i, yslice_w, res = 0.05) {
  ### set the number of row slices by cell_id: because cell_id scans rowwise,
  ### row 1 is 1-7200, 2 is 7201-14400, etc.
  x_px     <- 360 / res                  ### number of pixels in x axis
  px_per_deg <- 1 / res                  ### number of pixels per deg

  yrange_deg <- 90 - c((i-1), i) * yslice_w
  yrange_row  <- (90 - yrange_deg) * px_per_deg + c(1, 0) ### pad first by 1
  cellrange <- c(min(yrange_row - 1) * x_px + 1, max(yrange_row) * x_px)
}

get_sdm <- function(aphia_id,
                    scenario = c('Current',
                                  'RCP26_2050', 'RCP26_2100',
                                  'RCP45_2050', 'RCP45_2100',
                                  'RCP85_2050', 'RCP85_2100'),
                    cellrange = NULL,    ### one or two numeric values for cell_id
                    apply_thresh = TRUE,
                    batch_size = 1000,   ### files per duckdb query - tune on server
                    threads = 60,        ### cap duckdb worker threads - shared server!
                    memory_limit = '300GB') { ### cap duckdb memory - shared server!
  filestem <- here_aquax('sdm_by_id/FINAL_EMSDM_EMMEAN_SP_%s.parquet')
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
    ### files <- batches[[3]]
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
        "SELECT cell_id, cutoff, ", select_cols, ", ",
        "CAST(regexp_extract(filename, '_SP_([0-9]+)\\.parquet$', 1) AS INTEGER) AS aphia_id ",
        "FROM read_parquet(", file_list_sql, ", filename=true, union_by_name=true) ",
        "WHERE ", keep_clause
      )
    } else {
      select_cols <- paste(scenario, collapse = ', ')
      query_str <- paste0(
        "SELECT cell_id, cutoff, ", select_cols, ", ",
        "CAST(regexp_extract(filename, '_SP_([0-9]+)\\.parquet$', 1) AS INTEGER) AS aphia_id ",
        "FROM read_parquet(", file_list_sql, ", filename=true, union_by_name=true)"
      )
    }
    if(!is.null(cellrange)) {

      query_str <- paste0(
        query_str,
        if(apply_thresh) " AND cell_id <= " else " WHERE cell_id <= ", max(cellrange), " AND cell_id >= ", min(cellrange)
      )
    }
    DBI::dbGetQuery(con, query_str)
  }

  df_list <- lapply(batches, process_batch)
  df <- collapse::rowbind(df_list) %>%
    janitor::clean_names()

  return(df)
}

cell_id_to_xy <- function(df, cell_id_col = 'cell_id', res = 0.05, drop = TRUE) {
  ncols   <- as.integer(360 / res)
  ids     <- df[[cell_id_col]]
  col_idx <- ((ids - 1L) %% ncols) + 1L
  row_idx <- ((ids - 1L) %/% ncols) + 1L
  df <- df |>
    fmutate(x = round(col_idx * res - 180 - res/2, 3),
            y = round(90 - row_idx * res + res/2,  3)) |>
    select(x, y, everything())
  if(drop) df <- df |> select(-cell_id)
  return(df)
}

xy_to_cell_id <- function(df, x_col = 'x', y_col = 'y', res = 0.05, drop = TRUE) {
  ncols   <- as.integer(360 / res)
  x       <- df[[x_col]]
  y       <- df[[y_col]]
  col_idx <- as.integer(round((x + 180 + res/2) / res))
  row_idx <- as.integer(round((90 - y + res/2) / res))
  df <- df |>
    fmutate(cell_id = (row_idx - 1L) * ncols + col_idx) |>
    select(cell_id, everything())
  if(drop) df <- df |> select(-all_of(c(x_col, y_col)))
  return(df)
}


sample_decomp <- function(df) {
  ### MAJOR REWRITE - full vectorization and use of
  ### collapse::fsum etc within group objects - drop the skew and kurtosis
  ### for speed and ease
  
  # df <- tx_tmp_dfs %>% fsubset(x < -170 & scenario == 'rcp45_2050')
  g <- collapse::GRP(df, ~ cell_id + scenario)
  
  n     <- df$n
  mn    <- df$mean
  var_i <- df$sd^2
  
  ### broadcast pooled n and pooled mean back to row level (for deviations)
  pool_n_bc    <- collapse::fsum(n, g = g, TRA = "replace")
  pool_mean_bc <- collapse::fsum(n * mn, g = g, TRA = "replace") / pool_n_bc
  deviation    <- mn - pool_mean_bc
  
  SS <- (n - 1) * var_i
  SS[n == 1] <- 0
  
  ### group-level pooled n / mean / var / sd
  pool_n    <- collapse::fsum(n, g = g)
  pool_mean <- collapse::fsum(n * mn, g = g) / pool_n
  pool_dev_sum <- collapse::fsum(n * deviation^2, g = g)
  pool_SS   <- collapse::fsum(SS, g = g) + pool_dev_sum
  pool_var  <- pool_SS / (pool_n - 1)
  pool_sd   <- sqrt(pool_var)
  
  summary_df <- data.frame(
    cell_id = g$groups$cell_id,
    n    = pool_n,
    mean = pool_mean,
    sd   = pool_sd,
    row.names = NULL
  )
  
  return(summary_df)
}

