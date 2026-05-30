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
        ### this is used in mclapply, so just use dplyr instead of collapse
        mutate(across(.cols = c(x, y), ~round(.x, 3))) %>%
        mutate(across(.cols = scen, ~ifelse(.x < cutoff, NA, 1))) %>%
        filter(!if_all(.cols = scen, is.na))
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

### Rewriting utilities::sample.decomp to avoid the NA error
sample_decomp <- function (moments = NULL, n = NULL, sample.mean = NULL, sample.sd = NULL, 
          sample.var = NULL, sample.skew = NULL, sample.kurt = NULL, 
          names = NULL, pooled = NULL, skew.type = NULL, kurt.type = NULL, 
          kurt.excess = NULL, include.sd = FALSE) 
{
  if (!is.null(moments)) {
    if (!("moments" %in% class(moments))) {
      stop("Error: Input moments must be a moments object")
    }
    if (is.null(n)) {
      n <- moments$n
    }
    else {
      stop("Error: Input moments or descriptive statistics but not both")
    }
    if (is.null(sample.mean)) {
      sample.mean <- moments$sample.mean
    }
    else {
      stop("Error: Input moments or descriptive statistics but not both")
    }
    if ("sample.sd" %in% colnames(moments)) {
      if (is.null(sample.sd)) {
        sample.sd <- moments$sample.sd
      }
      else {
        stop("Error: Input moments or descriptive statistics but not both")
      }
    }
    if (is.null(sample.var)) {
      sample.var <- moments$sample.var
    }
    else {
      stop("Error: Input moments or descriptive statistics but not both")
    }
    if (is.null(sample.skew)) {
      sample.skew <- moments$sample.skew
    }
    else {
      stop("Error: Input moments or descriptive statistics but not both")
    }
    if (is.null(sample.kurt)) {
      sample.kurt <- moments$sample.kurt
    }
    else {
      stop("Error: Input moments or descriptive statistics but not both")
    }
    if (is.null(skew.type)) {
      skew.type <- attributes(moments)$skew.type
    }
    else {
      stop("Error: Input moments or skew.type but not both")
    }
    if (is.null(kurt.type)) {
      kurt.type <- attributes(moments)$kurt.type
    }
    else {
      stop("Error: Input moments or kurt.type but not both")
    }
    if (is.null(kurt.excess)) {
      kurt.excess <- attributes(moments)$kurt.excess
    }
    else {
      stop("Error: Input moments or kurt.excess but not both")
    }
    if (is.null(names)) {
      names <- rownames(moments)
    }
  }
  if (is.null(n)) {
    stop("Error: You must input n")
  }
  if (!is.vector(n)) {
    stop("Error: Input n should be a vector of positive integers")
  }
  if (!is.numeric(n)) {
    stop("Error: Input n should be a vector of positive integers")
  }
  if (any(as.integer(n) != n)) {
    stop("Error: Input n should be a vector of positive integers")
  }
  if (min(n) < 1) {
    stop("Error: Input n should be a vector of positive integers")
  }
  N <- length(n)
  MOMENTS <- rep(FALSE, 4)
  if (!is.null(sample.mean)) {
    MOMENTS[1] <- TRUE
  }
  if (!is.null(sample.var)) {
    MOMENTS[2] <- TRUE
  }
  if (!is.null(sample.sd)) {
    MOMENTS[2] <- TRUE
  }
  if (!is.null(sample.skew)) {
    MOMENTS[3] <- TRUE
  }
  if (!is.null(sample.kurt)) {
    MOMENTS[4] <- TRUE
  }
  MAXMOM <- 0
  if (MOMENTS[1]) {
    MAXMOM <- 1
  }
  if (prod(MOMENTS[1:2] == 1)) {
    MAXMOM <- 2
  }
  if (prod(MOMENTS[1:3] == 1)) {
    MAXMOM <- 3
  }
  if (prod(MOMENTS[1:4] == 1)) {
    MAXMOM <- 4
  }
  if (MOMENTS[1]) {
    if (!is.vector(sample.mean)) {
      stop("Error: Input sample.mean should be a numeric vector (if specified)")
    }
    if (!is.numeric(sample.mean)) {
      stop("Error: Input sample.mean should be a numeric vector (if specified)")
    }
    if (length(sample.mean) != N) {
      stop("Error: Input sample.mean must have the same length as n (if specified)")
    }
  }
  if (!is.null(sample.var)) {
    if (!is.vector(sample.var)) {
      stop("Error: Input sample.var should be a numeric vector (if specified)")
    }
    if (!is.numeric(sample.var)) {
      stop("Error: Input sample.var should be a numeric vector (if specified)")
    }
    if (length(sample.var) != N) {
      stop("Error: Input sample.var must have the same length as n (if specified)")
    }
    if (min(sample.var, na.rm = TRUE) < 0) {
      stop("Error: Values in sample.var cannot be negative")
    }
  }
  if (!is.null(sample.sd)) {
    if (!is.vector(sample.sd)) {
      stop("Error: Input sample.sd should be a numeric vector (if specified)")
    }
    if (!is.numeric(sample.sd)) {
      stop("Error: Input sample.sd should be a numeric vector (if specified)")
    }
    if (length(sample.sd) != N) {
      stop("Error: Input sample.sd must have the same length as n (if specified)")
    }
    if (min(sample.sd, na.rm = TRUE) < 0) {
      stop("Error: Values in sample.sd cannot be negative")
    }
  }
  if ((!is.null(sample.sd)) & (!is.null(sample.var))) {
    ERROR <- sum((sample.sd^2 - sample.var)^2, na.rm = TRUE)
    THRESHOLD <- (1e-10) * min(sample.sd, na.rm = TRUE)
    if (ERROR > THRESHOLD) {
      stop("Error: You may specify sample.sd or sample.var but not both")
    }
    else {
      warning("You have specified sample.sd and sample.var --- only sample.var is used for calculations")
    }
  }
  if ((!is.null(sample.sd)) & (is.null(sample.var))) {
    sample.var <- sample.sd^2
  }
  if (MOMENTS[3]) {
    if (!is.vector(sample.skew)) {
      stop("Error: Input sample.skew should be a numeric vector (if specified)")
    }
    if (!is.numeric(sample.skew)) {
      stop("Error: Input sample.skew should be a numeric vector (if specified)")
    }
    if (length(sample.skew) != N) {
      stop("Error: Input sample.skew must have the same length as n (if specified)")
    }
  }
  if (MOMENTS[4]) {
    if (!is.vector(sample.kurt)) {
      stop("Error: Input sample.kurt should be a numeric vector (if specified)")
    }
    if (!is.numeric(sample.kurt)) {
      stop("Error: Input sample.kurt should be a numeric vector (if specified)")
    }
    if (length(sample.kurt) != N) {
      stop("Error: Input sample.kurt must have the same length as n (if specified)")
    }
  }

  if (MAXMOM >= 3) {
    TYPES <- c("Moment", "Fisher Pearson", "Adjusted Fisher Pearson", 
               "b", "g", "G", "Minitab", "Excel", "SPSS", "SAS", 
               "Stata")
    if (is.null(skew.type)) {
      skew.type <- "Fisher Pearson"
    }
    if (!(skew.type %in% TYPES)) {
      stop("Error: Input skew.type not recognised")
    }
  }
  if (MAXMOM >= 4) {
    if (is.null(kurt.type)) {
      kurt.type <- "Fisher Pearson"
    }
    if (is.null(kurt.excess)) {
      kurt.excess <- FALSE
    }
    if (!(kurt.type %in% TYPES)) {
      stop("Error: Input kurt.type not recognised")
    }
    if (!is.vector(kurt.excess)) {
      stop("Error: Input kurt.excess should be a single logical value")
    }
    if (!is.logical(kurt.excess)) {
      stop("Error: Input kurt.excess should be a single logical value")
    }
    if (length(kurt.excess) != 1) {
      stop("Error: Input kurt.excess should be a single logical value")
    }
  }
  if (!is.vector(include.sd)) {
    stop("Error: Input include.sd should be a single logical value")
  }
  if (!is.logical(include.sd)) {
    stop("Error: Input include.sd should be a single logical value")
  }
  if (length(include.sd) != 1) {
    stop("Error: Input include.sd should be a single logical value")
  }
  if (MAXMOM >= 3) {
    skew.adj <- function(n) {
      A <- 1
      if (skew.type %in% c("Moment", "b", "Minitab")) {
        A <- ((n - 1)/n)^(3/2)
      }
      if (skew.type %in% c("Adjusted Fisher Pearson", 
                           "G", "Excel", "SPSS", "SAS")) {
        A <- sqrt(n * (n - 1))/(n - 2)
      }
      A
    }
  }
  if (MAXMOM >= 4) {
    kurt.adj <- function(n) {
      B <- 1
      if (kurt.type %in% c("Moment", "b", "Minitab")) {
        B <- ((n - 1)/n)^2
      }
      if (kurt.type %in% c("Adjusted Fisher Pearson", 
                           "G", "Excel", "SPSS", "SAS")) {
        B <- (n + 1) * (n - 1)/((n - 2) * (n - 3))
      }
      B
    }
    excess.adj <- function(n) {
      C <- -3 * kurt.excess
      if (kurt.type %in% c("Adjusted Fisher Pearson", 
                           "G", "Excel", "SPSS", "SAS")) {
        C <- -3 * kurt.excess * (n - 1)^2/((n - 2) * 
                                             (n - 3))
      }
      C
    }
  }
  if (is.null(pooled)) {
    pool.n <- sum(n)
    OUT <- data.frame(n = c(n, pool.n))
    if (!is.null(names)) {
      rownames(OUT)[1:N] <- names
    }
    rownames(OUT)[N + 1] <- "--pooled--"
    if (MAXMOM >= 1) {
      pool.mean <- sum(n * sample.mean)/pool.n
      deviation <- sample.mean - pool.mean
      OUT$sample.mean <- c(sample.mean, pool.mean)
    }
    if (MAXMOM >= 2) {
      SS <- (n - 1) * sample.var
      pool.SS <- sum(SS, na.rm = TRUE) + sum(n * deviation^2)
      pool.var <- pool.SS/(pool.n - 1)
      if (include.sd) {
        OUT$sample.sd <- c(sqrt(sample.var), sqrt(pool.var))
      }
      OUT$sample.var <- c(sample.var, pool.var)
    }
    if (MAXMOM >= 3) {
      SC <- sample.skew * (SS^(3/2))/(skew.adj(n) * sqrt(n))
      pool.SC <- sum(SC, na.rm = TRUE) + 3 * sum(SS * deviation, na.rm = TRUE) + sum(n * 
                                                           deviation^3)
      pool.skew <- skew.adj(pool.n) * sqrt(pool.n) * pool.SC/pool.SS^(3/2)
      OUT$sample.skew <- c(sample.skew, pool.skew)
    }
    if (MAXMOM >= 4) {
      SQ <- (sample.kurt - excess.adj(n)) * SS^2/(kurt.adj(n) * n)
      pool.SQ <- sum(SQ, na.rm = TRUE) + 4 * sum(SC * deviation, na.rm = TRUE) + 6 * 
        sum(SS * deviation^2, na.rm = TRUE) + sum(n * deviation^4)
      pool.kurt <- kurt.adj(pool.n) * pool.n * pool.SQ/pool.SS^2 + 
        excess.adj(pool.n)
      OUT$sample.kurt <- c(sample.kurt, pool.kurt)
    }
  }
  if (!is.null(pooled)) {
    pool.n <- n[pooled]
    part.n <- sum(n[-pooled])
    other.n <- pool.n - part.n
    OUT <- data.frame(n = c(n, other.n))
    if (!is.null(names)) {
      rownames(OUT)[1:N] <- names
    }
    rownames(OUT)[pooled] <- "--pooled--"
    rownames(OUT)[N + 1] <- "--other--"
    if (MAXMOM >= 1) {
      pool.mean <- sample.mean[pooled]
      part.mean <- sum(n[-pooled] * sample.mean[-pooled])/part.n
      other.mean <- (pool.n * pool.mean - part.n * part.mean)/other.n
      deviation <- sample.mean[-pooled] - part.mean
      OUT$sample.mean <- c(sample.mean, other.mean)
    }
    if (MAXMOM >= 2) {
      SS <- (n[-pooled] - 1) * sample.var[-pooled]
      part.SS <- sum(SS, na.rm = TRUE) + sum(n[-pooled] * deviation^2)
      pool.SS <- (pool.n - 1) * sample.var[pooled]
      other.SS <- pool.SS - part.SS - (part.n * pool.n/other.n) * 
        (part.mean - pool.mean)^2
      other.var <- other.SS/(other.n - 1)
      if (include.sd) {
        OUT$sample.sd <- c(sqrt(sample.var), sqrt(other.var))
      }
      OUT$sample.var <- c(sample.var, other.var)
    }
    if (MAXMOM >= 3) {
      SC <- sample.skew[-pooled] * SS^(3/2)/(skew.adj(n[-pooled]) * 
                                               sqrt(n[-pooled]))
      part.SC <- sum(SC, na.rm = TRUE) + 3 * sum(SS * deviation, na.rm = TRUE) + sum(n[-pooled] * 
                                                           deviation^3)
      pool.SC <- sample.skew[pooled] * pool.SS^(3/2)/(skew.adj(pool.n) * 
                                                        sqrt(pool.n))
      other.SC <- pool.SC - part.SC - (3 * (pool.n * part.SS - 
                                              part.n * pool.SS)/(other.n)) * (part.mean - 
                                                                                pool.mean) - ((pool.n * part.n) * (pool.n + 
                                                                                                                     part.n)/(other.n)^2) * (part.mean - pool.mean)^3
      other.skew <- skew.adj(other.n) * sqrt(other.n) * 
        other.SC/other.SS^(3/2)
      OUT$sample.skew <- c(sample.skew, other.skew)
    }
    if (MAXMOM >= 4) {
      SQ <- (sample.kurt[-pooled] - excess.adj(n[-pooled])) * 
        SS^2/(kurt.adj(n[-pooled]) * n[-pooled])
      part.SQ <- sum(SQ, na.rm = TRUE) + 4 * sum(SC * deviation, na.rm = TRUE) + 6 * 
        sum(SS * deviation^2, na.rm = TRUE) + sum(n[-pooled] * deviation^4)
      pool.SQ <- (sample.kurt[pooled] - excess.adj(pool.n)) * 
        pool.SS^2/(kurt.adj(pool.n) * pool.n)
      other.SQ <- pool.SQ - part.SQ - 4 * ((pool.n * other.SC - 
                                              other.n * pool.SC)/(pool.n - other.n)) * (other.mean - 
                                                                                          pool.mean) - 6 * ((pool.n^2 * other.SS - other.n^2 * 
                                                                                                               pool.SS)/(pool.n - other.n)^2) * (other.mean - 
                                                                                                                                                   pool.mean)^2 - ((other.n * pool.n^3 + other.n^2 * 
                                                                                                                                                                      pool.n^2 + other.n^3 * pool.n)/(pool.n - other.n)^3) * 
        (other.mean - pool.mean)^4
      other.kurt <- kurt.adj(other.n) * other.n * other.SQ/other.SS^2 + 
        excess.adj(other.n)
      OUT$sample.kurt <- c(sample.kurt, other.kurt)
    }
    ORDER <- 1:(N + 1)
    ORDER <- ORDER[-pooled]
    ORDER[N + 1] <- pooled
    OUT <- OUT[ORDER, ]
  }
  attr(OUT, "skew.type") <- skew.type
  attr(OUT, "kurt.type") <- kurt.type
  attr(OUT, "kurt.excess") <- kurt.excess
  ### was just to return OUT; now return OUT just the row named --pooled--
  OUT['--pooled--', ]
}

