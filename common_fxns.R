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
