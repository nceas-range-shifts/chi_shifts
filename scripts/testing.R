# remotes::install_version("utilities", version = "0.4.0")
library(utilities)
library(moments)
library(tidyverse)

df <- data.frame(v = as.numeric(log(runif(n = 1000)))) %>%
  mutate(xy = rep(letters[1:10], times = 100),
         gp = rep(LETTERS[11:20], each = 100)) %>%
  bind_rows(data.frame(xy = 'a', gp = 'Z', v = 7))

all <- df %>%
  group_by(xy) %>%
  summarize(m = mean(v), sd = sd(v), sk = skewness(v), k = kurtosis(v), n = n())

pooled_sd <- function(m, s, n, m_all = NULL) {
  ### convert std dev to var
  v <- ifelse(is.na(s), 0, s^2)
  ### calc overall mean if not provided
  if(is.null(m_all)) m_all <- fsum(m * n) / fsum(n)
  
  prefix <- 1/(sum(n - 1))
  first_term <- sum((n - 1) * v + n * m^2)
  second_term <- sum(n) * m_all
  
  pooled_v <- prefix * (first_term + second_term)
  pooled_sd <- sqrt(pooled_v)

  return(pooled_sd)
}

gps <- df %>% 
  group_by(xy, gp) %>% 
  summarize(m = mean(v), sd = sd(v), sk = skewness(v), k = kurtosis(v), n = n(), .groups = 'drop')

gp_sum1 <- gps %>%
  group_by(xy) %>%
  do(sample_decomp(n = .$n, sample.mean = .$m, sample.sd = .$sd, sample.skew = .$sk, sample.kurt = .$k, include.sd = TRUE))
gp_sum2 <- gps %>%
  group_by(xy) %>%
  reframe(sample_decomp(n = n, sample.mean = m, sample.sd = sd, sample.skew = sk, sample.kurt = k))

gp_sum3 <- gps %>%
  group_by(xy) %>%
  summarize(mean = weighted.mean(x = m, w = n), sd = pooled_sd(m, sd, n, m_all = mean))

pooled_stats <- function(df) {
  sample.decomp(n = df$n, sample.mean = df$mean, sample.sd = df$sd, sample.skew = df$skew, sample.kurt = df$kurt) %>%
    filter(n == max(n))
}

gp_sum <- gps %>%
  fgroup_by(xy) %>%
  fsummarize(sample.decomp(n = n, sample.mean = m, sample.sd = sd, sample.skew = sk, sample.kurt = k)) %>%
  fgroup_by(xy) %>%
  fsubset(n == max(n))

results <- sample.decomp(
  n = gps$n, 
  sample.mean = gps$m, 
  sample.sd   = gps$sd, 
  sample.skew = gps$sk,
  sample.kurt = gps$k
)

sample_decomp <- function(df) {
  results <- sample.decomp(
    n = df$n, 
    sample.mean = df$m, 
    sample.sd   = df$sd, 
    sample.skew = df$sk,
    sample.kurt = df$k
  )
}