# 1. Calculate expenditure shares

## 1.1 expenditure shares  π_{ni}^j
panel_full <- read_csv("2. Data Cleaning/improvement_panel_full.csv")

shares <- panel_full %>% 
  group_by(dest, sector, year) %>% 
  mutate(pi = value / sum(value, na.rm = TRUE)) %>% 
  ungroup()

## 1.2 self-shares π_nn^j  and  π_ii^j
self_pi <- shares %>% 
  filter(origin == dest) %>% 
  select(prov = origin, sector, year, pi_self = pi) 

shares <- shares %>% 
  left_join(self_pi,  by = c("dest"   = "prov", "sector", "year")) %>% 
  rename(pi_nn = pi_self) %>% 
  left_join(self_pi,  by = c("origin" = "prov", "sector", "year")) %>% 
  rename(pi_ii = pi_self)

## 1.3 reverse-flow share π_{in}^j
shares <- shares %>% 
  left_join(
    shares %>% 
      select(origin_rev = origin, dest_rev = dest, sector, year, pi_rev = pi),
    by = c("origin" = "dest_rev", "dest" = "origin_rev", "sector", "year")
  ) %>% 
  rename(pi_in = pi_rev, pi_ni = pi) 

## 1.4 τ̄_{ni}^j
shares_clean <- shares %>%
  filter(pi_ni > 0, pi_in > 0, pi_nn > 0, pi_ii > 0) %>%
  mutate(
    tau_bar = ((pi_nn * pi_ii) / (pi_ni * pi_in))^(1/(2*theta))
  )

# 3. Gravity Regressions
dist_mat_final <- read_csv("1. Distance Calculation/dist_mat_final.csv")

shares_dist <- shares_clean %>% 
  left_join(dist_mat_final, by = c("origin", "dest")) %>% 
  filter(!sector %in% c("Construction", 
                        "Public administration and defence; compulsory social security", 
                        "Utilities"))

shares_dist <- shares_dist %>%
  mutate(
    log_tau = log(tau_bar),
    log_dist = log(distance),
    intra_dummy = if_else(origin %in% provsplus & dest %in% provsplus & origin == dest, 1, 0),
  ) %>%
  mutate(
    expyr = interaction(origin, year, drop = TRUE),
    impyr = interaction(dest,   year, drop = TRUE),
  )


# Extract geographic and non-geographic components
non_distance_cost_results_final <- data.frame()

# Get a list of sectors to loop over
sectors_to_regress <- unique(shares_dist$sector)

for (s in sectors_to_regress) {
  
  sector_data <- shares_dist %>% filter(sector == s)
  
  # Run the cost gravity model
  geo_mod <- feols(
    log_tau ~ distance + neighbour + intra_dummy
    | expyr + impyr,
    cluster = ~ origin + dest,
    data     = sector_data
  )
  
  # Calculate the purely geographic component of cost
  # 1. Extract the raw coefficients
  beta_dist <- coef(geo_mod)["distance"]
  gamma_neigh <- coef(geo_mod)["neighbour"]
  
  # 2. Calculate the non-distance cost factor in one step
  # Formula: (Total Cost / Geographic Cost) - 1
  # Geographic Cost = exp(beta*dist + gamma*neigh)
  sector_data <- sector_data %>%
    mutate(
      tau_NG = (tau_bar / exp(beta_dist * distance
                              + gamma_neigh * neighbour))
    )
  
  sector_data <- sector_data %>%
    mutate(
      tau_cf_raw = exp(beta_dist * distance +
                         gamma_neigh * neighbour),
      tau_counterfactual = pmin(tau_cf_raw, tau_bar)
    )
  
  non_distance_cost_results_final <- rbind(non_distance_cost_results_final, sector_data)
}

write_csv(shares_dist, "3. Shares Calculation/improvement_full_data.csv")
write_csv(non_distance_cost_results_final, "3. Shares Calculation/improvement_non_distance.csv")
