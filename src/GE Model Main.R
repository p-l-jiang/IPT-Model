# RUN ALL SCRIPTS IN FOLDERS 1-3 FIRST

# 0. Setup 
## 0.1 Install/load required packages
library(purrr)
packages <- c(
  "dplyr", "tidyr", "janitor", "readr", "stringr", "fixest", "geosphere",
  "cansim", "Matrix", "data.table", "arrow", "parallelly", "here",
  "tidyverse", "stringdist", "tibble", "scales", "tidyverse", "knitr")

install_if_missing <- function(pkg) if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
walk(packages, install_if_missing)
walk(packages, library, character.only = TRUE)

setwd("C:/Users/JiangPe/Documents/1. Internal Trade/Internal Trade GE Model based on Tombe/1. GE Model")

options(scipen = 999)

## 0.2 Definitions
provs <- c("AB","BC","MB","NB","NL","NS","ON","PE","QC","SK")
provsplus <- c("AB","BC","MB","NB","NL","NS","ON","PE","QC","SK","YT","NT","NU")
provinces <- c("Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia", "New Brunswick", "Quebec", 
               "Ontario", "Manitoba", "Saskatchewan", "Alberta", "British Columbia")
provincesplus <- c("Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia", "New Brunswick", "Quebec", 
                   "Ontario", "Manitoba", "Saskatchewan", "Alberta", "British Columbia", 
                   "Yukon", "Northwest Territories", "Nunavut")

supc_to_sector <- readRDS("2. Data Cleaning/GE_model_data/supc_to_sector.rds")
supc_to_sector2 <- readRDS("2. Data Cleaning/GE_model_data/supc_to_sector2.rds")
theta_data <- readRDS("2. Data Cleaning/GE_model_data/theta_data.rds")

# ===================================================================================
# ADAPTED MODEL SOLVER FOR TOMBE IMPROVEMENT (2022)
# ===================================================================================

# 1. DATA PREPARATION
# Extract 2022 data slice (Year 2022 is index 28 in the 1995-2020 array)
load("2. Data Cleaning/ICIO2025econZ.RData")
load("2. Data Cleaning/ICIO2025econFD.RData")
load("2. Data Cleaning/ICIO2025econVA.RData")
load("2. Data Cleaning/ICIO2025econGTR.RData") 
load("2. Data Cleaning/ICIO2025econX.RData")

Z_2022 <- ICIO2025econZ[28, , ]
FD_2022 <- ICIO2025econFD[28, , ]
VA_2022 <- ICIO2025econVA[28, ]
X_2022 <- ICIO2025econX[28, ]

TARGET_YEAR <- 2022
REGIONS <- c(provsplus, "USA", "ROW")

sut_product_to_sector_map <- readRDS("2. Data Cleaning/GE_model_data/sut_product_to_sector_map.rds")
ind_map <- readRDS("2. Data Cleaning/GE_model_data/ind_map.rds")

SECTORS <- unique(sut_product_to_sector_map$sector) 

# Calculate World VA Shares for CAN, USA, ROW from ICIO data
fx <- fread("2. Data Cleaning/FXUSDCAD.csv")
fx[, date := as.IDate(date, format = "%m/%d/%Y")]
fx[, year := year(date)]

fx_rate_2022 <- fx[year == 2022,
                   .(cad_per_usd = mean(value, na.rm = TRUE)),
                   by = year] %>%
  pull(cad_per_usd)

vadd_cad <- VA_2022 * fx_rate_2022

oecd_country_codes <- substr(names(vadd_cad), 1, 3)

oecd_region_map <- case_when(
  oecd_country_codes == "CAN" ~ "CAN",
  oecd_country_codes == "USA" ~ "USA",
  TRUE                        ~ "ROW"
)

cou_map <- data.frame(
  country = unique(oecd_country_codes),
  stringsAsFactors = FALSE
) %>%
  mutate(region = case_when(
    country == "CAN" ~ "CAN",
    country == "USA" ~ "USA",
    TRUE ~ "ROW"
  ))

# Load Provincial and Trade Data
shares_dist <- read_csv("3. Shares Calculation/improvement_full_data.csv")
non_distance_cost_results_final <- read_csv("3. Shares Calculation/improvement_non_distance.csv")

# --- Load 2022 Provincial SUT Data ---
clean_sut_names <- function(names_vector) { gsub("\\s*\\[.*\\]$", "", names_vector) }

sut_folder <- "15-602-x_csv-scsv_2022_eng/"
sut_supply_raw <- read_csv(paste0(sut_folder, "SUT_C2022_D.csv"), show_col_types = FALSE) %>%
  filter(`Supply and use` == "Supply") %>% 
  mutate(Industry = clean_sut_names(Industry), 
         Product = clean_sut_names(Product),
         VALUE = VALUE / 1000)

sut_use_raw <- read_csv(paste0(sut_folder, "SUT_C2022_D.csv"), show_col_types = FALSE) %>%
  filter(`Supply and use` == "Use") %>% 
  mutate(Industry = clean_sut_names(Industry), 
         Product = clean_sut_names(Product),
         VALUE = VALUE / 1000)

# 2: MODEL PARAMETER CONSTRUCTION (2022 DATA)
## 2.1 Omega (ω): Regional Income Shares

# Aggregate the CAD value added by region
world_va_cad <- data.frame(region = oecd_region_map, va = vadd_cad) %>%
  group_by(region) %>%
  summarise(total_va_cad = sum(va, na.rm = TRUE)) %>%
  mutate(world_share = total_va_cad / sum(total_va_cad))

# --- c) Calculate Provincial Shares within Canada ---
omega_data <- read_csv("improvement_omega_data.csv")

# --- d) Combine for final omega_vec ---
can_world_share <- world_va_cad$world_share[world_va_cad$region == "CAN"]
usa_world_share <- world_va_cad$world_share[world_va_cad$region == "USA"]
row_world_share <- world_va_cad$world_share[world_va_cad$region == "ROW"]

# Calculate each province's share of the world total
prov_world_shares <- setNames(
  omega_data$omega_can_share * can_world_share,
  omega_data$Province
)

# Combine into the final vector
omega_full_vec <- c(prov_world_shares, "USA" = usa_world_share, "ROW" = row_world_share)

# Ensure the final vector is ordered correctly according to the REGIONS constant
omega_full_vec <- omega_full_vec[REGIONS]
omega_full_vec[is.na(omega_full_vec)] <- 0 # Set any missing regions (e.g., if a territory has no GDP data) to 0

# --- 2.2 Gamma (γ): Input-Output Matrix ---
# The matrix of intermediate input shares. The element gamma[k, j] is the
# share of user j's inputs that come from provider k.
# --- a) Define the Aggregation Map ---
# This maps each of the 3420 OECD country-industry rows/columns to a model sector.
oecd_industry_codes <- substr(colnames(Z_2022), 5, 9)
oecd_sector_map <- ind_map$paper_sector[match(oecd_industry_codes, ind_map$oecd_code)]

# --- b) Aggregate the Global Z-Matrix ---
# This is a two-step process: first aggregate the rows (providers), then the columns (users).

# Step 1: Aggregate the 3,420 rows (providers) into model's sectors.
# The result is a [number_of_sectors x 3420] matrix.
Z_agg_rows <- rowsum(Z_2022, group = oecd_sector_map, reorder = TRUE, na.rm = TRUE)

# Step 2: Aggregate the 3,420 columns (users) into model's sectors.
# We transpose, aggregate the new rows, and transpose back.
Z_agg_final <- t(rowsum(t(Z_agg_rows), group = oecd_sector_map, reorder = TRUE, na.rm = TRUE))

# --- c) Normalize to get the Final Gamma Matrix ---
# Ensure the matrix is complete and ordered correctly before normalizing.
gamma_matrix_unaligned <- Z_agg_final
gamma_matrix <- matrix(0, nrow=length(SECTORS), ncol=length(SECTORS), dimnames=list(SECTORS, SECTORS))
common_dims <- intersect(rownames(gamma_matrix_unaligned), SECTORS)
gamma_matrix[common_dims, common_dims] <- gamma_matrix_unaligned[common_dims, common_dims]

# Normalize by column sum to get the technical coefficients
gamma_matrix <- sweep(gamma_matrix, 2, colSums(gamma_matrix, na.rm = TRUE), FUN = "/")
gamma_matrix[is.na(gamma_matrix)] <- 0

# --- 2.3 Phi (φ): Value-Added Share Matrix [region, sector] ---
# Calculate Total Output and Value Added
OUTPUT_vec <- X_2022
OUTPUT_matrix <- matrix(OUTPUT_vec, ncol = 1, dimnames = list(names(OUTPUT_vec), "OUTPUT"))

output_map <- ind_map$paper_sector[match(substr(names(OUTPUT_vec), 5, 9), ind_map$oecd_code)]

OUTPUT_agg <- rowsum(OUTPUT_matrix, group = output_map, reorder = TRUE, na.rm = TRUE)

VADD_vec <- VA_2022
VADD_matrix <- matrix(VADD_vec, ncol = 1, dimnames = list(names(VADD_vec), "VADD"))

VADD_agg <- rowsum(VADD_matrix, group = output_map, reorder = TRUE, na.rm = TRUE)


# Create the final phi_matrix by broadcasting the sector ratios across all regions
phi_j_ratios <- VADD_agg / OUTPUT_agg

phi_j_ordered <- phi_j_ratios[SECTORS, 1]

# Replicate the vector of ratios for each region to build the matrix
phi_matrix <- matrix(
  data = phi_j_ordered,
  nrow = length(REGIONS),
  ncol = length(SECTORS),
  byrow = TRUE, # Replicate the row vector for each region
  dimnames = list(REGIONS, SECTORS)
)

phi_matrix[is.na(phi_matrix) | is.infinite(phi_matrix)] <- 0

# --- 2.4 Beta (β): Final Demand Share Matrix ---

# a) Define patterns to identify all final demand categories using grepl.
# This is more robust than listing every single unique category name.
final_demand_patterns <- c(
  "final consumption expenditure",
  "Gross fixed capital formation",
  "Changes in inventories",
  "^Construction,", # Captures GFCF in construction
  "^Machinery and equipment,", # Captures GFCF in M&E
  "^Intellectual property products," # Captures GFCF in IPP
)

# Combine patterns into a single regex string with OR operators `|`
search_pattern <- paste(final_demand_patterns, collapse = "|")

# b) Calculate provincial final demand levels by sector from the SUT Use table
prov_fd_levels <- sut_use_raw %>%
  # Filter for rows where the 'Industry' column matches one of our patterns
  filter(
    Valuation == "Basic price",
    grepl(search_pattern, Industry), 
    GEO %in% provincesplus) %>%
  # Map the detailed SUT products to your model's sectors
  left_join(sut_product_to_sector_map_use, by = c("Product" = "sut_product")) %>%
  filter(!is.na(sector)) %>%
  # Sum the values to get total final demand for each sector in each province
  group_by(origin = GEO, sector) %>%
  summarise(fd_value = sum(VALUE, na.rm = TRUE), .groups = "drop") %>%
  # Recode province names 
  mutate(origin = dplyr::recode(origin,
                         "Alberta" = "AB", 
                         "British Columbia" = "BC", 
                         "Manitoba" = "MB",
                         "New Brunswick" = "NB", 
                         "Newfoundland and Labrador" = "NL",
                         "Nova Scotia" = "NS", 
                         "Ontario" = "ON", 
                         "Prince Edward Island" = "PE",
                         "Quebec" = "QC",
                         "Saskatchewan" = "SK",
                         "ROW" = "ROW",
                         "Yukon" = "YT", 
                         "Northwest Territories" = "NT",
                         "Nunavut" = "NU"))

# c) Normalize to get provincial expenditure shares (the provincial part of beta)
prov_beta_shares <- prov_fd_levels %>%
  group_by(origin) %>%
  mutate(share = fd_value / sum(fd_value, na.rm = TRUE)) %>%
  ungroup()

# d) Reshape into a wide matrix [sectors x provinces]
prov_beta_matrix <- prov_beta_shares %>%
  select(origin, sector, share) %>%
  pivot_wider(
    names_from = origin,
    values_from = share,
    values_fill = 0
  ) %>%
  column_to_rownames("sector") %>%
  as.matrix()

# e) Create and populate the final, complete beta_matrix (Same as before)
beta_matrix <- matrix(0, nrow = length(SECTORS), ncol = length(REGIONS), 
                      dimnames = list(SECTORS, REGIONS))

# Use intersect() for a robust assignment of the provincial data
common_rows <- intersect(rownames(beta_matrix), rownames(prov_beta_matrix))
common_cols <- intersect(colnames(beta_matrix), colnames(prov_beta_matrix))
beta_matrix[common_rows, common_cols] <- prov_beta_matrix[common_rows, common_cols]

# f) Populate USA & ROW shares from the aggregated OECD data (same as before)
# Create the region map for the 81 columns
# This is the key fix for your error
oecd_country_codes <- dimnames(ICIO2025econFD)[[3]]

oecd_region_map <- case_when(
  oecd_country_codes == "CAN" ~ "CAN",
  oecd_country_codes == "USA" ~ "USA",
  TRUE                      ~ "ROW"
)

# --- Step 2: Perform the aggregation ---

# Aggregate rows by providing sector (this should work now)
fd_agg_by_provider <- rowsum(FD_2022, group = oecd_sector_map, reorder = TRUE, na.rm = TRUE)

# Aggregate columns by destination region (this is the step that previously failed)
# It will now work because oecd_region_map has the correct length (81)
fd_agg_final <- t(rowsum(t(fd_agg_by_provider), group = oecd_region_map, reorder = TRUE, na.rm = TRUE))

# Clean up any potential NA values that result from removing Canada
fd_agg_final[is.na(fd_agg_final)] <- 0

beta_shares_agg <- sweep(fd_agg_final, 2, colSums(fd_agg_final, na.rm = TRUE), FUN = "/")
beta_matrix[, "USA"] <- beta_shares_agg[SECTORS, "USA"]
beta_matrix[, "ROW"] <- beta_shares_agg[SECTORS, "ROW"]

# Final cleanup 
beta_matrix[beta_matrix < 0] <- 0
beta_matrix <- sweep(beta_matrix, 2, colSums(beta_matrix, na.rm = TRUE), FUN = "/")
beta_matrix[is.na(beta_matrix)] <- 0

## 2.5 Pi (π): Trade Share Array (Simplified and Corrected)
# ===================================================================================

# Initialize the 3D array
pi_array <- array(0, dim = c(length(REGIONS), length(REGIONS), length(SECTORS)),
                  dimnames = list(dest = REGIONS, origin = REGIONS, sector = SECTORS))

# --- Step 1: Calculate all expenditure shares from your complete trade flow data ---
pi_shares <- shares_dist %>%
  filter(year == TARGET_YEAR) %>%
  # For each destination and sector, calculate the share of spending for each origin
  group_by(dest, sector) %>%
  mutate(share = value / sum(value, na.rm = TRUE)) %>%
  ungroup() %>%
  # Ensure we only use regions and sectors defined in the model
  filter(dest %in% REGIONS, origin %in% REGIONS, sector %in% SECTORS)

# --- Step 2: Fill the entire pi_array from these shares ---
# This correctly populates all off-diagonal (trade) and diagonal (home) shares.
for (i in 1:nrow(pi_shares)) {
  row <- pi_shares[i, ]
  # Check to prevent errors if a value is somehow NA
  if (!is.na(row$share)) {
    pi_array[row$dest, row$origin, row$sector] <- row$share
  }
}

# --- Step 3: Final Normalization (optional but good practice) ---
# This ensures all destination-sector slices sum exactly to 1, correcting for any minor rounding errors.
for (d in REGIONS) {
  for (s in SECTORS) {
    total <- sum(pi_array[d, , s], na.rm = TRUE)
    if (total > 0) {
      pi_array[d, , s] <- pi_array[d, , s] / total
    } else {
      # If a region has no expenditure in a sector, set its home share to 1.
      # This prevents NaNs and assumes it is self-sufficient in products it doesn't trade.
      pi_array[d, d, s] <- 1
    }
  }
}

pi_array[is.na(pi_array)] <- 0 # Final cleanup

# --- 2.6 Theta (θ) Vector ---
theta_vec <- setNames(theta_data$theta, theta_data$sector)[SECTORS]

saveRDS(pi_array, file = "2. Data Cleaning/GE_model_data/pi_array.rds")
saveRDS(gamma_matrix, file = "2. Data Cleaning/GE_model_data/gamma_matrix.rds")
saveRDS(phi_matrix, file = "2. Data Cleaning/GE_model_data/phi_matrix.rds")
saveRDS(theta_vec, file = "2. Data Cleaning/GE_model_data/theta_vec.rds")
saveRDS(beta_matrix, file = "2. Data Cleaning/GE_model_data/beta_matrix.rds")
saveRDS(omega_full_vec, file = "2. Data Cleaning/GE_model_data/omega_full_vec.rds")

# ===================================================================================
#  MODEL SOLVER WITH LABOR MIGRATION
# ===================================================================================
solve_model_matrix <- function(tau_hat_array, pi_array, gamma_matrix, phi_matrix, 
                               theta_vec, beta_matrix, omega_vec, experiment_name,
                               migration_elasticity = 0, # NEW: Set to > 0 to enable migration
                               max_iter = 5000, tolerance = 1e-9) {
  
  region_names <- dimnames(pi_array)[[1]]
  sector_names <- dimnames(pi_array)[[3]]
  num_regions <- length(region_names)
  num_sectors <- length(sector_names)
  
  # Identify Canadian provinces for the migration calculation
  canadian_provinces <- region_names[region_names %in% provsplus]
  
  # Initialize variables
  w_hat <- rep(1, num_regions)
  names(w_hat) <- region_names
  
  # NEW: Initialize labor supply change vector (L_hat)
  L_hat <- rep(1, num_regions)
  names(L_hat) <- region_names
  
  p_hat <- matrix(1, nrow = num_regions, ncol = num_sectors, 
                  dimnames = list(region_names, sector_names))
  initial_income <- setNames(omega_vec, region_names)
  
  cat(paste("Starting solver for:", experiment_name, 
            "| Migration Elasticity:", migration_elasticity, "\n"))
  
  for (iter in 1:max_iter) {
    w_hat_old <- w_hat
    
    # --- Inner loop to find p_hat for given w_hat and L_hat ---
    for (p_iter in 1:100) {
      p_hat_old_inner <- p_hat
      
      term1_log_wages <- log(w_hat) %o% rep(1, num_sectors)
      term2_log_prices_sum <- log(p_hat) %*% gamma_matrix
      term2_full <- term2_log_prices_sum * (1 - phi_matrix)
      c_hat <- exp(term1_log_wages * phi_matrix + term2_full)
      dimnames(c_hat) <- list(region_names, sector_names)
      
      p_hat_numerator_terms <- array(0, dim = dim(pi_array), dimnames = dimnames(pi_array))
      for (s in sector_names) {
        c_hat_mat_s <- matrix(c_hat[, s], nrow = num_regions, ncol = num_regions, byrow = FALSE)
        cost_shock_term <- (tau_hat_array[, , s] * t(c_hat_mat_s))^(-theta_vec[s])
        p_hat_numerator_terms[, , s] <- pi_array[, , s] * cost_shock_term
      }
      
      p_hat_sum_term <- apply(p_hat_numerator_terms, c("dest", "sector"), sum, na.rm = TRUE)
      theta_matrix <- matrix(theta_vec[sector_names], nrow = num_regions, ncol = num_sectors, byrow = TRUE)
      p_hat_new <- p_hat_sum_term^(-1 / theta_matrix)
      p_hat_new[is.infinite(p_hat_new) | is.na(p_hat_new)] <- 1
      
      if (max(abs(p_hat_new - p_hat_old_inner), na.rm = TRUE) < 1e-10) break
      p_hat <- p_hat_new
    }
    
    # --- Calculate new trade shares (pi_prime) ---
    p_hat_sum_array <- array(0, dim = dim(p_hat_numerator_terms), dimnames = dimnames(p_hat_numerator_terms))
    for (o_idx in 1:dim(p_hat_sum_array)[2]) {
      p_hat_sum_array[, o_idx, ] <- p_hat_sum_term
    }
    pi_prime <- p_hat_numerator_terms / p_hat_sum_array
    pi_prime[is.na(pi_prime)] <- 0
    
    # --- Calculate counterfactual expenditures ---
    # NEW: Counterfactual income now depends on BOTH wage changes and labor supply changes.
    I_prime <- w_hat * L_hat * initial_income
    
    Xf_prime <- I_prime * t(beta_matrix[sector_names, region_names])
    dimnames(Xf_prime) <- list(region_names, sector_names)
    
    X_prime <- Xf_prime
    for (i in 1:50) {
      R_prime_list <- vapply(sector_names, function(j) {
        t(pi_prime[, , j]) %*% X_prime[, j]
      }, FUN.VALUE = numeric(num_regions))
      R_prime <- matrix(R_prime_list, nrow = num_regions, dimnames = list(region_names, sector_names))
      R_prime[is.na(R_prime) | is.infinite(R_prime)] <- 0
      
      Xi_prime <- (R_prime * (1 - phi_matrix)) %*% t(gamma_matrix)
      dimnames(Xi_prime) <- list(region_names, sector_names)
      Xi_prime[is.na(Xi_prime) | is.infinite(Xi_prime)] <- 0
      
      X_prime_new <- Xf_prime + Xi_prime
      if (max(abs(X_prime_new - X_prime), na.rm = TRUE) < 1e-10) break
      X_prime <- X_prime_new
    }
    
    # --- NEW: Labor Supply Update ---
    if (migration_elasticity > 0) {
      # Calculate real wage change (utility change) for this iteration
      beta_ordered <- beta_matrix[dimnames(p_hat)[[2]], dimnames(p_hat)[[1]]]
      log_p_hat <- log(p_hat)
      log_p_hat[is.infinite(log_p_hat) | is.na(log_p_hat)] <- 0
      log_price_level_change <- diag(log_p_hat %*% beta_ordered)
      price_level_change <- exp(log_price_level_change)
      u_hat <- w_hat / price_level_change
      
      # Calculate national average utility change (U_hat) for Canadian provinces
      can_omega <- omega_vec[canadian_provinces]
      can_u_hat_sum <- sum((can_omega / sum(can_omega)) * u_hat[canadian_provinces]^migration_elasticity)
      U_hat_can <- can_u_hat_sum^(1 / migration_elasticity)
      
      # Update provincial labor supply (L_hat)
      L_hat[canadian_provinces] <- (u_hat[canadian_provinces] / U_hat_can)^migration_elasticity
      
      # L_hat for USA and ROW remains 1 (no migration)
      L_hat[!(names(L_hat) %in% canadian_provinces)] <- 1
    }
    
    # --- Update Wages ---
    Generated_VA_prime <- rowSums(R_prime * phi_matrix, na.rm = TRUE)
    
    # NEW: The update ratio now also includes the change in labor supply
    update_ratio <- Generated_VA_prime / (L_hat * initial_income)
    w_hat_new <- update_ratio
    w_hat_new[is.na(w_hat_new) | is.infinite(w_hat_new)] <- 1
    
    # Normalize wages using world income shares
    w_hat_new <- w_hat_new / sum(w_hat_new * L_hat * omega_vec, na.rm = TRUE)
    
    # Dampening
    w_hat <- 0.1 * w_hat_new + 0.9 * w_hat_old
    
    if (max(abs(w_hat - w_hat_old), na.rm = TRUE) < tolerance) {
      cat("Converged after", iter, "iterations.\n")
      
      # Return the final L_hat vector along with the solution
      return(list(w_hat = w_hat, p_hat = p_hat, L_hat = L_hat))
    }
  }
  
  warning("Solver did not converge after ", max_iter, " iterations.")
  return(list(w_hat = w_hat, p_hat = p_hat, L_hat = L_hat))
}

# ===================================================================================
# 4. EXPERIMENT EXECUTION
# ===================================================================================

analyze_and_display_results <- function(solution_object, experiment_name,
                                        beta_matrix, omega_vector,
                                        regions_vector, provinces_vector) {
  
  # --- 1. Calculate Core Outcome Variables ---
  
  # Calculate the change in the aggregate price level for each region
  price_level_change <- exp(diag(log(solution_object$p_hat) %*% beta_matrix[dimnames(solution_object$p_hat)[[2]], regions_vector]))
  
  # Calculate Per-Capita GDP Gain (Real Wage Change)
  gdp_gain_per_capita <- solution_object$w_hat / price_level_change
  
  # Calculate Aggregate Real GDP Change (Accounts for population change)
  gdp_gain_aggregate <- (solution_object$w_hat * solution_object$L_hat) / price_level_change
  
  # --- 2. Create the Detailed Results Table ---
  
  results_detailed <- data.frame(
    Region = regions_vector,
    `Per-Capita GDP Gain (%)` = (gdp_gain_per_capita[regions_vector] - 1) * 100,
    `Population Change (%)` = (solution_object$L_hat[regions_vector] - 1) * 100,
    `Aggregate Real GDP Change (%)` = (gdp_gain_aggregate[regions_vector] - 1) * 100,
    check.names = FALSE
  )
  
  # --- 3. Calculate the Canada-wide Aggregate Change ---
  
  agg_gdp_change_pct <- (gdp_gain_aggregate[regions_vector] - 1) * 100
  canada_gdp_change <- agg_gdp_change_pct[provinces_vector]
  canada_weights <- omega_vector[provinces_vector]
  canada_weights_normalized <- canada_weights / sum(canada_weights)
  canada_aggregate_change <- sum(canada_gdp_change * canada_weights_normalized)
  
  # --- 4. Print Formatted Output ---
  
  cat("\n-------------------------------------------------------------------\n")
  # Use knitr::kable for clean, markdown-ready tables
  print(knitr::kable(results_detailed, digits = 4, caption = experiment_name))
  cat("\nCanada Aggregate Real GDP Change (Initial GDP-weighted):", round(canada_aggregate_change, 4), "%\n")
  cat("-------------------------------------------------------------------\n")
}

# Define the migration elasticity. A value of 1.5 is 2019 paper assumption
# Set this to 0 to replicate the no-migration results.
elasticity_of_migration <- 0

# --- Replicate Table 5 Policy Experiments ---

# T5, Col 4: 10% Lower Internal Canadian Trade Costs
tau_t5_c4 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (d in REGIONS) {
  for (o in REGIONS) {
    if (d %in% provsplus && o %in% provsplus && d != o) {
      tau_t5_c4[d, o, ] <- 0.9
    }
  }
}

solution_t5_c4 <- solve_model_matrix(
  tau_hat_array = tau_t5_c4, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "10% Lower Internal Canadian Trade Costs",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_t5_c4,
  experiment_name = "10% Lower Internal Canadian Trade Costs",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# T5, Col 5: 10% Lower External Trade Costs (Canada-US-ROW)
tau_t5_c5 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (d in REGIONS) {
  for (o in REGIONS) {
    # External means: not both Canadian provinces
    if (!(d %in% provsplus && o %in% provsplus) && d != o) {
      tau_t5_c5[d, o, ] <- 0.9
    }
  }
}

solution_t5_c5 <- solve_model_matrix(
  tau_hat_array = tau_t5_c5, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "10% Lower External Canadian Trade Costs",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_t5_c5,
  experiment_name = "10% Lower External Canadian Trade Costs",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# --- 4.3 Replicate Table 6 Policy Experiments ---

GOODS_SECTORS <- c("Agriculture, hunting, forestry, fishing and aquaculture",              
                   "Mining and quarrying, energy producing products",               
                   "Mining and quarrying, non-energy producing products",              
                   "Food products, beverages and tobacco",             
                   "Textiles, textile products, leather and footwear",            
                   "Wood and products of wood and cork",           
                   "Paper products and printing",          
                   "Coke and refined petroleum products",         
                   "Chemical and pharmaceutical products",        
                   "Rubber and plastics products",       
                   "Other non-metallic mineral products",      
                   "Basic metals",     
                   "Fabricated metal products",    
                   "Machinery and equipment, nec",   
                   "Computer, electronic and optical equipment",  
                   "Electrical equipment", 
                   "Motor vehicles, trailers and semi-trailers",
                   "Other transport equipment",
                   "Manufacturing nec; repair and installation of machinery and equipment")

# T6, Col 1: 10% Lower Measured Internal Costs
tau_t6_c1 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (i in 1:nrow(shares_dist)) {
  row <- shares_dist[i, ]
  if (row$origin %in% provsplus && row$dest %in% provsplus && 
      row$origin != row$dest && !is.na(row$tau_bar) && row$tau_bar > 1) {
    tau_hat <- (1 + 0.9 * (row$tau_bar - 1)) / row$tau_bar
    if (row$sector %in% GOODS_SECTORS) {
      tau_t6_c1[row$dest, row$origin, row$sector] <- tau_hat
    }
  }
}

solution_t6_c1 <- solve_model_matrix(
  tau_hat_array = tau_t6_c1, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "10% Lower Measured Internal Trade Costs",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_t6_c1,
  experiment_name = "10% Lower Measured Internal Trade Costs",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# T6, Col 4: Eliminate Non-Distance Barriers for Goods
tau_t6_c4 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (i in 1:nrow(non_distance_cost_results_final)) {
  row <- non_distance_cost_results_final[i, ]
  if (!is.na(row$tau_counterfactual)&& row$sector %in% GOODS_SECTORS &&
      row$origin %in% provsplus && row$dest %in% provsplus) {
    tau_t6_c4[row$dest, row$origin, row$sector] <- row$tau_counterfactual
  }
}

solution_t6_c4 <- solve_model_matrix(
  tau_hat_array = tau_t6_c4, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "Eliminate Non-Distance Barriers for Goods",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_t6_c4,
  experiment_name = "Eliminate Non-Distance Barriers for Goods",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# T6, Col 5: Eliminate All Measured Internal Costs
tau_t6_c5 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (i in 1:nrow(shares_dist)) {
  row <- shares_dist[i, ]
  if (row$origin %in% provsplus && row$dest %in% provsplus && 
      row$origin != row$dest && !is.na(row$tau_bar) && row$tau_bar > 0) {
    if (row$sector %in% GOODS_SECTORS) {
      tau_t6_c5[row$dest, row$origin, row$sector] <- 1 / row$tau_bar
    }
  }
}

solution_t6_c5 <- solve_model_matrix(
  tau_hat_array = tau_t6_c5, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "Eliminate All Measured Internal Costs",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_t6_c5,
  experiment_name = "Eliminate All Measured Internal Costs",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# ===================================================================================
# EXPERIMENT: U.S. Tariffs
# ===================================================================================

# Set this to 0 to replicate the no-migration results.
elasticity_of_migration <- 0

# Experiment 1: US imposes 35% tariffs for all other regions
cat("\n--- Running Experiment 1: US 35% Universal Tariff ---\n")

tau_exp1 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (origin_region in REGIONS) {
  if (origin_region != "USA") {
    tau_exp1["USA", origin_region, ] <- 1.35
  }
}

solution_exp1 <- solve_model_matrix(
  tau_hat_array = tau_exp1, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "US 35% Universal Tariff",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_exp1,
  experiment_name = "US 35% Universal Tariff",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# Experiment 2: US imposes 50% tariffs on metals for all other regions
cat("\n--- Running Experiment 2: US 50% Metals Tariff ---\n")

tau_exp2 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
metals_sectors <- c("Basic metals", "Fabricated metal products")
for (origin_region in REGIONS) {
  if (origin_region != "USA") {
    tau_exp2["USA", origin_region, metals_sectors] <- 1.50
  }
}

solution_exp2 <- solve_model_matrix(
  tau_hat_array = tau_exp2, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "US 50% Metals Tariff",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_exp2,
  experiment_name = "US 50% Metals Tariff",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# Experiment 3: Scenario 1 + Canada retaliation
cat("\n--- Running Experiment 3: US Universal Tariff + Canada Retaliation ---\n")

tau_exp3 <- tau_exp1 # Start with the tariff from Experiment 1

for (dest in provsplus) {
    tau_exp3[dest, "USA", ] <- 1.35
}

solution_exp3 <- solve_model_matrix(
  tau_hat_array = tau_exp3, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, experiment_name = "US Universal Tariff + Canada Retaliation",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_exp3,
  experiment_name = "US Universal Tariff + Canada Retaliation",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# Experiment 4: Scenario 3 + CAN/ROW retaliation
cat("\n--- Running Experiment 4: US 35% Tariff + CAN/ROW Retaliation ---\n")

tau_exp4 <- tau_exp3 

# ROW retaliation
tau_exp4["ROW", "USA", ] <- 1.35

solution_exp4 <- solve_model_matrix(
  tau_hat_array = tau_exp4, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, experiment_name = "US Universal Tariff + CAN/ROW Retaliation",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_exp4,
  experiment_name = "US Universal Tariff + CAN/ROW Retaliation",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# Experiment 5: Scenario 2 + Canada and ROW retaliation
cat("\n--- Running Experiment 5: US Metals Tariff + CAN/ROW Metals Retaliation ---\n")

tau_exp5 <- tau_exp2
for (province_dest in provsplus) {
    tau_exp5[province_dest, "USA", metals_sectors] <- 1.50
}
tau_exp5["ROW", "USA", metals_sectors] <- 1.50

solution_exp5 <- solve_model_matrix(
  tau_hat_array = tau_exp5, pi_array = pi_array, gamma_matrix = gamma_matrix,
  phi_matrix = phi_matrix, theta_vec = theta_vec, beta_matrix = beta_matrix,
  omega_vec = omega_full_vec, 
  experiment_name = "US Metals Tariff + CAN/ROW Metals Retaliation",
  migration_elasticity = elasticity_of_migration
)

analyze_and_display_results(
  solution_object = solution_exp5,
  experiment_name = "US Metals Tariff + CAN/ROW Metals Retaliation",
  beta_matrix = beta_matrix,
  omega_vector = omega_full_vec,
  regions_vector = REGIONS,
  provinces_vector = provsplus
)

# Function to analyze and display sectoral-level results for a specific region
analyze_sectoral_results_by_region <- function(solution_object, experiment_name,
                                               region_name, sectors_vector) {
  
  # --- 1. Extract Variables for Specific Region ---
  
  # Get wage change for the specific region
  w_hat_region <- solution_object$w_hat[region_name]
  
  # Get price changes by sector for the specific region
  p_hat_region <- solution_object$p_hat[region_name, sectors_vector]
  
  # Get labor reallocation for the specific region
  L_hat_region <- solution_object$L_hat[region_name]
  
  # --- 2. Calculate Sectoral GDP Changes for the Region ---
  
  sectoral_gdp_changes <- numeric(length(sectors_vector))
  names(sectoral_gdp_changes) <- sectors_vector
  
  for (s in sectors_vector) {
    # GDP change = wage change * labor change / price change
    sectoral_gdp_changes[s] <- (w_hat_region * L_hat_region) / p_hat_region[s]
  }
  
  # --- 3. Create Results Table ---
  
  results_sectoral <- data.frame(
    Sector = sectors_vector,
    `Sectoral GDP Change (%)` = round((sectoral_gdp_changes - 1) * 100, 2),
    check.names = FALSE
  )
  
  # Sort by GDP impact (most negative to least negative)
  results_sectoral <- results_sectoral[order(results_sectoral$`Sectoral GDP Change (%)`, 
                                             decreasing = TRUE), ]
  
  # --- 4. Print Formatted Output ---
  
  cat("\n=====================================================================\n")
  cat(region_name, "SECTORAL BREAKDOWN:", experiment_name, "\n")
  cat("=====================================================================\n\n")
  
  # Print table
  print(knitr::kable(results_sectoral, 
                     digits = 2,
                     align = c('l', 'r'),
                     caption = paste(region_name, "Sectoral GDP Changes")))
  
  # --- 5. Summary Statistics ---
  
  cat("\nSummary Statistics for", region_name, ":\n")
  cat("Most Affected Sector:", results_sectoral$Sector[nrow(results_sectoral)], 
      "(", results_sectoral$`Sectoral GDP Change (%)`[nrow(results_sectoral)], "%)\n")
  cat("Least Affected Sector:", results_sectoral$Sector[1], 
      "(", results_sectoral$`Sectoral GDP Change (%)`[1], "%)\n")
  cat("Average Sectoral GDP Change:", 
      round(weighted.mean(results_sectoral$`Sectoral GDP Change (%)`), 2), "%\n")
  
  cat("=====================================================================\n")
  
  # Return the results
  return(results_sectoral)
}

# Example usage with the Tombe model:
# After running a trade experiment, call the sectoral analysis function

ontario_sectoral_results <- analyze_sectoral_results_by_region(
  solution_object = solution_exp4,  # Use the experiment solution object
  experiment_name = "US Universal Tariff + CAN/ROW Retaliation",
  region_name = "ON",  # Ontario's code
  sectors_vector = SECTORS # All sectors
)

