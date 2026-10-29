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

cut_problem_depths <- function(meta) {
  ### * Keep all benthic/demersal spp regardless of depth
  ### * Keep all neritic species
  ### * Keep all species whose max depth is 200m or less (epipelagic)
  meta |> 
    filter((neritic == 1) | depth_range_deep <= 200 | benthic == 1 | demersal == 1)
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

parquet_to_rast <- function(f, param = NULL, scenario = NULL, behrmann = TRUE) {
  df <- read_parquet(f)
  if('stat' %in% names(df)) {
    if(is.null(param)) param = 'mean'
    df <- df |> 
      fsubset(stat == param) |> 
      select(-stat)
  }
  if(is.null(scenario)) {
    scenario <- names(df)[!names(df) %in% c('cell_id')]
  }
  r <- df |>
    cell_id_to_xy() |>
    select(x, y, all_of(scenario)) |>
    rast() |>
    extend(ext(-180, 180, -90, 90))
  crs(r) <- 'epsg:4326'
  if(behrmann) {
    ocean_r <- get_ocean_rast()
    r <- project(r, ocean_r)
  }
  return(r)
}

get_ocean_rast <- function() {
  ### use nspp tif file and flatten to ocean cells - note, all layers
  ### have zero instead of NA for ocean cells with no spp
  r <- rast(here::here('_output/spp_turnover_maps/all_spp_richness.tif'))[[1]]
  r[!is.na(r)] <- 1
  names(r) <- 'ocean'
  return(r)
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


plot_map <- function(data, fill_var, lat_color = 'grey30') {
  ### this creates a plot of data, given x, y in a Behrmann projection
  data <- data |>
    filter(!is.na({{ fill_var }}))
  ggplot() +
    geom_raster(data = data, aes(x, y, fill = {{ fill_var }})) +
    map_theme(lat_color = lat_color)
}

map_theme <- function(lat_color = 'grey30') {
  if(!exists('land_sf')) {
    land_sf <- sf::read_sf(here('_data/mregions_2026/world_continents.gpkg')) |> 
      st_transform(crs = crs(get_ocean_rast()))
    assign('land_sf', land_sf, envir = .GlobalEnv)
  }
  ### add onto a ggplot map, more flexibility in defining the
  ### raster
  list(
    ### continents:
    geom_sf(data = land_sf,
            fill = 'grey96', color = 'grey50',
            size = .1),
    ### tropics and equator:
    geom_hline(yintercept = c(2907724.470, -2907275.530),
               linetype = 'dashed', linewidth = 0.25, color = lat_color),
    geom_hline(yintercept = 0,
               linetype = 'solid', linewidth = 0.25, color = lat_color),
    ### standardized styling:
    scale_x_continuous(expand = c(0, 0)),
    scale_y_continuous(expand = c(0, 0)),
    theme_void()
  )
}


plot_marginal <- function(df, var, data_range = c(-1, 1)) {

  summary_df <- df |>
    ### NOTE: fsummarize doesn't recognize {{ var }} notation
    ### Round to nearest 50km-ish to reduce plotting load
    mutate(y = round(y * 2, -5) / 2) |> 
    group_by(y) |> 
    summarize(m = fmean({{ var }}),
              s = fsd({{ var }}),
              max = fmax({{ var }}),
              min = fmin({{ var }})) |> 
    arrange(y)
  yrange <- range(df$y)

  ggplot(summary_df) +
    geom_segment(data = data.frame(x = seq(data_range[1], data_range[2], .01)),
                aes(x = x, color = x), linewidth = 1,
                y = yrange[1], yend = yrange[2],
                show.legend = FALSE) +
    scale_color_gradient2(low = pal[1], mid = pal[2], high = pal[3],
                          limits = data_range) +
    geom_path(aes(x = m, y = y)) +
    geom_ribbon(aes(xmin = min, xmax = max, y = y), alpha = .20) +
    geom_ribbon(aes(xmin = m - s, xmax = m + s, y = y), alpha = .30) +
    geom_vline(xintercept = 0, color = 'grey30') +
    ### tropics and equator:
    geom_hline(yintercept = c(2907724.470, -2907275.530),
              linetype = 'dashed', linewidth = 0.25, color = 'grey30') +
    geom_hline(yintercept = 0,
              linetype = 'solid', linewidth = 0.25, color = 'grey30') +
    scale_x_continuous(limits = data_range, 
                      breaks = c(min(data_range), 0, max(data_range))) +
    scale_y_continuous(expand = c(0, 0)) +
    theme_minimal() +
    theme(axis.text.y = element_blank(), 
          panel.grid = element_blank(),
          axis.text.x = element_text(family = 'Helvetica'),
          axis.title = element_blank())
}
