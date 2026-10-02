# 0. Setup 
## 0.1 Install/load required packages
library(purrr)
packages <- c(
  "dplyr", "tidyr", "janitor", "readr", "stringr", "fixest", "geosphere",
  "cansim", "Matrix", "data.table", "arrow", "qs", "parallelly", "here",
  "tidyverse", "stringdist", "tibble", "scales", "tidyverse", "knitr", "OECD")

install_if_missing <- function(pkg) if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
walk(packages, install_if_missing)
walk(packages, library, character.only = TRUE)

setwd("C:/Users/JiangPe/Documents/R/Tombe Replication")

options(scipen = 999)

# save.image(file = "Tombe2015-07-15.RData")
# load(file = "Tombe2015-07-15.RData")

## 0.2 Definitions
provs <- c("AB","BC","MB","NB","NL","NS","ON","PE","QC","SK")
provsplus <- c("AB","BC","MB","NB","NL","NS","ON","PE","QC","SK","YT","NT","NU")
provinces <- c("Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia", "New Brunswick", "Quebec", 
               "Ontario", "Manitoba", "Saskatchewan", "Alberta", "British Columbia")
provincesplus <- c("Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia", "New Brunswick", "Quebec", 
                   "Ontario", "Manitoba", "Saskatchewan", "Alberta", "British Columbia", 
                   "Yukon", "Northwest Territories", "Nunavut")

supc_to_sector <- tribble(
  ~supc_sector,                                                   ~sector,
  "Grains and other crop products"                                , "Agriculture, Mining",
  "Live animals"                                                  , "Agriculture, Mining",
  "Other farm products"                                           , "Agriculture, Mining",
  "Forestry products and services"                                , "Agriculture, Mining",
  "Fish, crustaceans, shellfish and other fishery products"       , "Agriculture, Mining",
  "Support services related to farming and forestry"              , "Agriculture, Mining",
  "Mineral fuels"                                                 , "Agriculture, Mining",
  "Metal ores and concentrates"                                   , "Agriculture, Mining",
  "Non-metallic minerals"                                         , "Agriculture, Mining",
  "Mining and oil and gas support services"                       , "Agriculture, Mining",
  "Oil and gas and mineral exploration"                           , "Agriculture, Mining",
  "Utilities"                                                     , "Utilities",
  "Residential buildings"                                         , "Construction",
  "Non-residential buildings (except mine buildings)"             , "Construction",
  "Engineering works"                                             , "Construction",
  "Repair construction services"                                  , "Construction",
  "Food and non-alcoholic beverages"                              , "Food, Textiles",
  "Alcoholic beverages and tobacco products"                      , "Food, Textiles",
  "Textile products, clothing, and products of leather and similar materials" , "Food, Textiles",
  "Wood products"                                                 , "Wood",
  "Wood pulp, paper and paper products and paper stock"           , "Paper",
  "Printed products and services"                                 , "Paper",
  "Chemical products"                                             , "Chemicals, Rubber",
  "Plastic and rubber products"                                   , "Chemicals, Rubber",
  "Refined petroleum products (except petrochemicals)"            , "Chemicals, Rubber",
  "Primary metallic products"                                     , "Metals",
  "Non-metallic mineral products"                                 , "Metals",
  "Fabricated metallic products"                                  , "Metals",
  "Computers and electronic products"                             , "Equipment, Vehicles",
  "Transportation equipment"                                      , "Equipment, Vehicles",
  "Electrical equipment, appliances and components"               , "Equipment, Vehicles",
  "Industrial machinery"                                          , "Equipment, Vehicles",
  "Motor vehicle parts"                                           , "Equipment, Vehicles",
  "Furniture and related products"                                , "Manufacturing, n.e.c.",
  "Other manufactured products and custom work"                   , "Manufacturing, n.e.c.",
  "Wholesale margins and commissions"                             , "Wholesale and Retail",
  "Retail margins, sales of used goods and commissions"           , "Wholesale and Retail",
  "Transportation and related services"                           , "Transport",
  "Transportation margins"                                        , "Transport",
  "Telecommunications, broadcasting distribution and related services" , "Communication",
  "Depository credit intermediation"                              , "Finance",
  "Other finance and insurance"                                   , "Finance",
  "Real estate, rental and leasing and rights to non-financial intangible assets" , "Real Estate",
  "Imputed rental of owner-occupied dwellings"                    , "Real Estate",
  "Software"                                                      , "Software",
  "Professional services (except software and research and development)" , "Other Business Services",
  "Research and development"                                      , "Other Business Services",
  "Administrative and support, head office, waste management and remediation services" , "Other Business Services",
  "Education services"                                            , "Education",
  "Education services provided by government sector"              , "Education",
  "Health services provided by government sector"                 , "Health and Social",
  "Health and social assistance services"                         , "Health and Social",
  "Arts, entertainment and recreation services"                   , "Other Services",
  "Accommodation and food services"                               , "Hotels and Restaurants",
  "Other services"                                                , "Other Services",
  "Information and cultural services"                             , "Other Services",
  "Published products and recorded media (except software)"       , "Other Services",
  "Sales of other services by Non-Profit Institutions Serving Households" , "Public Admin.",
  "Sales of other government services"                            , "Public Admin.",
  "Services provided by Non-Profit Institutions Serving Households", "Public Admin.",
  "Other federal government services"                             , "Public Admin.",
  "Other provincial and territorial government services"          , "Public Admin.",
  "Other municipal government services"                           , "Public Admin.",
  "Other aboriginal government services"                          , "Public Admin."
)

sector_to_theta <- tribble(
  ~sector, ~theta,
  "Agriculture, Mining", 11.92,
  "Food, Textiles", 4.56,  
  "Wood", 10.83,
  "Paper", 9.07,
  "Chemicals, Rubber", 19.16,
  "Metals", 5.02,
  "Equipment, Vehicles", 6.19,
  "Manufacturing, n.e.c.", 5.00,
  "Utilities", 5.00,
  "Wholesale and Retail", 5.00,
  "Hotels and Restaurants", 5.00,
  "Transport", 5.00,
  "Communication", 5.00,
  "Finance", 5.00,
  "Real Estate", 5.00,
  "Software", 5.00,
  "Other Business Services", 5.00,
  "Education", 5.00, 
  "Health and Social", 5.00,
  "Other Services", 5.00,
  "Public Admin.", 5.00,
  "Construction", 5.00
)

## 0.3 Data pull
### Interprovincial trade
trade_connection <- get_cansim_connection("12-10-0088-01") 

trade_raw <- trade_connection %>% 
  filter(REF_DATE == 2010,
         GEO %in% provinces, 
         !`Trade flow detail` %in% c("Total supply and demand",
                                     "Total supply",
                                     "Total demand")) %>% 
  collect_and_normalize() %>% 
  select(Province = GEO, year = REF_DATE, `Trade flow detail`, Product, VALUE)

trade_rare <- trade_raw %>% 
  filter(!Product %in% c("Total products",
                         "Total goods", 
                         "Total services", 
                         "Taxes on products",
                         "Fictive materials",
                         "Fictive services",
                         "Subsidies on products",
                         "Subsidies on production",
                         "Taxes on production",
                         "Wages and salaries",
                         "Employers' social contributions",
                         "Gross mixed income",
                         "Gross operating surplus"))

### GDP data
gdp_connection <- get_cansim_connection("36-10-0221-01")

gdp_raw <- gdp_connection %>% 
  filter(REF_DATE == 2010,
         GEO %in% provinces,
         `Estimates` == "Gross domestic product at market prices") %>% 
  collect_and_normalize() 

### Spatial price data
price_connection <- get_cansim_connection("18-10-0003-01")

price_raw <- price_connection %>% 
  filter(REF_DATE == 2010,
         `Products and product groups` == "All-items") %>% 
  collect_and_normalize() 

### OECD data
load("IOTs_2023ed_R/ICESHRE.rdata")
load("IOTs_2023ed_R/NATIOdomimp.rdata")
load("IOTs_2023ed_R/NATIOttl.rdata")
load("IOTs_2023ed_R/natLEONTFD.rdata")
load("IOTs_2023ed_R/natLEONTFT.rdata")

### FX Data
fx <- fread("FXUSDCAD.csv")
fx[, date := as.IDate(date, format = "%m/%d/%Y")]
fx[, year := year(date)]

fx_rate_2010 <- fx[year == 2010,
             .(cad_per_usd = mean(value, na.rm = TRUE)),
             by = year] %>% 
  pull(cad_per_usd)

## 0.4 Clean data
## 0.4 Cleaning raw data
dest_cols <- unique(trade_rare$`Trade flow detail`) %>% str_subset("^To ")

int_exp <- trade_rare %>%
  filter(`Trade flow detail` == "International exports") %>% 
  mutate(dest = "ROW") %>% 
  select(origin = Province, dest, Product, value = VALUE)

int_imp <- trade_rare %>% 
  filter(`Trade flow detail` == "International imports") %>% 
  mutate(origin = "ROW") %>% 
  select(origin, dest = Province, Product, value = VALUE)

internal_flows <- trade_rare %>% 
  filter(`Trade flow detail` %in% dest_cols) %>% 
  mutate(dest = str_sub(`Trade flow detail`, 4)) %>% 
  filter(dest %in% provinces) %>% 
  select(origin = Province, dest, Product, value = VALUE)

flows <- bind_rows(internal_flows, int_exp, int_imp) %>% 
  mutate(
    origin = recode(origin,
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
                    "ROW" = "ROW"),
    dest   = recode(dest,
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
                    "ROW" = "ROW"),
    supc_sector = Product) %>% 
  clean_names()

flows_isic <- flows %>% 
  left_join(supc_to_sector, by = "supc_sector") %>% 
  left_join(sector_to_theta, by = "sector")

trade_flows_final <- flows_isic %>%
  group_by(origin, dest, sector, theta) %>%
  summarise(value = sum(value, na.rm = TRUE), .groups = "drop")

write_csv(trade_flows_final, "2015_replication_panel_full.csv")
panel_full <- read_csv("2015_replication_panel_full.csv")

gdp_data <- gdp_raw %>% 
  mutate(
    Province = recode(GEO,
                 "Alberta" = "AB", 
                 "British Columbia" = "BC", 
                 "Manitoba" = "MB",
                 "New Brunswick" = "NB", 
                 "Newfoundland and Labrador" = "NL",
                 "Nova Scotia" = "NS", 
                 "Ontario" = "ON", 
                 "Prince Edward Island" = "PE",
                 "Quebec" = "QC",
                 "Saskatchewan" = "SK"),
    gdp_value = VALUE) %>% 
  select(Province, gdp_value)

spatial_price_data <- price_raw %>% 
  mutate(
    Province = recode(GEO,
                      "Edmonton, Alberta" = "AB", 
                      "Vancouver, British Columbia" = "BC", 
                      "Winnipeg, Manitoba" = "MB",
                      "Saint John, New Brunswick" = "NB", 
                      "St. John's, Newfoundland and Labrador" = "NL",
                      "Halifax, Nova Scotia" = "NS", 
                      "Ottawa-Gatineau, Ontario part, Ontario/Quebec" = "ON",
                      "Toronto, Ontario" = "ON",
                      "Charlottetown and Summerside, Prince Edward Island" = "PE",
                      "Montréal, Quebec" = "QC",
                      "Regina, Saskatchewan" = "SK")) %>% 
  group_by(Province) %>% 
  mutate(
    price_index = mean(VALUE)) %>% 
  select(Province, price_index) %>% 
  distinct()
  
# 1. Calculate expenditure shares
## 1.1 expenditure shares  π_{ni}^j
shares <- panel_full %>% 
  group_by(dest, sector) %>% 
  mutate(pi = value / sum(value, na.rm = TRUE)) %>% 
  ungroup()

## 1.2 self-shares π_nn^j  and  π_ii^j
self_pi <- shares %>% 
  filter(origin == dest) %>% 
  select(prov = origin, sector, pi_self = pi) 

shares <- shares %>% 
  left_join(self_pi,  by = c("dest"   = "prov", "sector")) %>% 
  rename(pi_nn = pi_self) %>% 
  left_join(self_pi,  by = c("origin" = "prov", "sector")) %>% 
  rename(pi_ii = pi_self)

## 1.3 reverse-flow share π_{in}^j
shares <- shares %>% 
  left_join(
    shares %>% 
      select(origin_rev = origin, dest_rev = dest, sector, pi_rev = pi),
    by = c("origin" = "dest_rev", "dest" = "origin_rev", "sector")
  ) %>% 
  rename(pi_in = pi_rev, pi_ni = pi) 

## 1.4 τ̄_{ni}^j
shares_clean <- shares %>%
  filter(pi_ni > 0, pi_in > 0, pi_nn > 0, pi_ii > 0) %>%
  mutate(
    tau_bar = ((pi_nn * pi_ii) / (pi_ni * pi_in))^(1/(2*theta))
  )

# 2. Distance calculation based on provincial capitals
da_raw <- read.csv("2006_92-151-XBB.csv", stringsAsFactors=TRUE)

names(da_raw) <- toupper(names(da_raw))

da_data <- da_raw %>%
  select(PRENAME, lat = DALAT, lon = DALONG, Population = DBPOP2006) %>%
  mutate(
    prov = recode(PRENAME,
                  "Alberta"="AB",
                  "British Columbia"="BC",
                  "Manitoba"="MB",
                  "New Brunswick"="NB",
                  "Newfoundland and Labrador"="NL",
                  "Nova Scotia"="NS",
                  "Ontario"="ON",
                  "Prince Edward Island"="PE",
                  "Quebec"="QC",
                  "Saskatchewan"="SK",
                  "Yukon"="YT",
                  "Nunavut"="NU",
                  "Northwest Territories"="NT"
    ),) %>%
  filter(prov %in% provsplus, !is.na(prov), !is.na(Population)) %>% 
  mutate(
    Population = as.numeric(Population),
    lat = as.numeric(lat),
    lon = as.numeric(lon)
  ) %>%
  filter(!is.na(lat) & !is.na(lon) & !is.na(Population))

prov_centroids <- da_data %>%
  group_by(prov) %>%
  summarise(
    lon = weighted.mean(lon, Population, na.rm = TRUE),
    lat = weighted.mean(lat, Population, na.rm = TRUE)
  )

d_nn_calc <- da_data %>%
  left_join(prov_centroids, by = "prov", suffix = c("_da", "_prov")) %>%
  mutate(
    dist_to_centroid = distHaversine(cbind(lon_da, lat_da), cbind(lon_prov, lat_prov)) / 1000
  ) %>%
  group_by(prov) %>%
  summarise(
    d_nn = weighted.mean(dist_to_centroid, Population, na.rm = TRUE)
  )

dist_mat <- expand_grid(origin = provs, dest = provs) %>%
  left_join(prov_centroids, by = c("origin" = "prov")) %>% rename(lat_o = lat, lon_o = lon) %>%
  left_join(prov_centroids, by = c("dest"   = "prov")) %>% rename(lat_d = lat, lon_d = lon) %>%
  mutate(
    # Between-province distance (d_ni) is centroid-to-centroid
    distance = distHaversine(cbind(lon_o, lat_o), cbind(lon_d, lat_d)) / 1000
  ) %>%
  # Join the within-province distances (d_nn and d_ii)
  left_join(d_nn_calc, by = c("origin" = "prov")) %>% rename(d_nn_o = d_nn) %>%
  left_join(d_nn_calc, by = c("dest"   = "prov")) %>% rename(d_nn_d = d_nn) %>%
  # For intra-province pairs, distance is d_nn. For others, it's centroid-to-centroid.
  mutate(
    distance = ifelse(origin == dest, d_nn_o, distance)
  )

# 3. Gravity Regressions
shares_dist <- shares_clean %>% 
  left_join(dist_mat, by = c("origin", "dest")) %>% 
  filter(!sector %in% c("Construction", 
                        "Public Admin.", 
                        "Utilities"))

shares_dist <- shares_dist %>%
  mutate(
    log_tau = log(tau_bar),
    log_dist = log(distance)
  )

geo_mod <- feols(
  log_tau ~ log_dist | origin + dest,
  cluster = ~ origin + dest,
  data = shares_dist
)

# Extract geographic and non-geographic components
shares_dist <- shares_dist %>%
  mutate(
    log_tau_geo = predict(geo_mod),
    tau_geo = exp(log_tau_geo),
    tau_NG = tau_bar / tau_geo
  )

write_csv(shares_dist, "2015_replication_full_data.csv")

full_data <- read_csv("2015_replication_full_data.csv")

# Define constants
n_regions <- length(provs)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Part 1: Prepare I-O Parameters (phi, beta, gamma)
# This section repeats the previous steps to make the script self-contained.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# --- Define Mappings and Constants ---
TARGET_COUNTRY <- "CAN"
TARGET_YEAR <- "2010"
PROVINCES <- c("AB", "BC", "MB", "NB", "NL", "NS", "ON", "PE", "QC", "SK")
REGIONS <- c(PROVINCES, "ROW") # ROW = Rest of World

# Industry mapping from OECD codes to Paper sectors
industry_mapping <- tibble::tribble(
  ~paper_sector,            ~oecd_code,
  "Agriculture, Mining",    "A01_02", "Agriculture, Mining",    "A03",
  "Agriculture, Mining",    "B05_06", "Agriculture, Mining",    "B07_08",
  "Food, Textiles",         "C10T12", "Food, Textiles",         "C13T15",
  "Wood",                   "C16",    "Paper",                  "C17_18",
  "Chemicals, Rubber",      "C19",    "Chemicals, Rubber",      "C20",
  "Chemicals, Rubber",      "C21",    "Chemicals, Rubber",      "C22",
  "Metals",                 "C23",    "Metals",                 "C24",
  "Metals",                 "C25",
  "Equipment, Vehicles",    "C26",    "Equipment, Vehicles",    "C27",
  "Equipment, Vehicles",    "C28",    "Equipment, Vehicles",    "C29",
  "Equipment, Vehicles",    "C30",
  "Manufacturing, n.e.c.",  "C31T33", "Utilities",              "D",
  "Utilities",              "E",      "Construction",           "F",
  "Wholesale and Retail",   "G",      "Transport",              "H49",
  "Transport",              "H50",    "Transport",              "H51",
  "Transport",              "H52",    "Transport",              "H53",
  "Hotels and Restaurants", "I",      "Other Services",          "J58T60",
  "Communication",          "J61",    "Finance",                "K",
  "Real Estate",            "L",      "Software",               "J62_63",
  "Other Business Services","M",      "Other Business Services","N",
  "Public Admin.",          "O",      "Education",              "P",
  "Health and Social",      "Q",      "Other Services",         "R",
  "Other Services",         "S",      "Other Services",         "T"
)
SECTORS <- unique(industry_mapping$paper_sector)

# --- Extract and Calculate I-O Parameters ---
io_table_2010 <- NATIOttl[TARGET_YEAR, TARGET_COUNTRY, , ]
industry_cols <- dimnames(io_table_2010)[[2]][1:45]
industry_rows <- dimnames(io_table_2010)[[1]][1:45]

# For calculating ROW GDP
TARGET_YEAR <- "2010"
TARGET_COUNTRY_EXCLUDE <- "CAN"
GDP_ROW_CODE <- "VALU" 

# 2. Get a list of all countries available in the NATIOttl data for 2010
all_countries_2010 <- dimnames(NATIOttl[TARGET_YEAR, , , ])[[1]]

# 3. Calculate GDP (Total Value Added) for every country
# This loops through each country code, extracts its 2010 data,
# and sums its total value added across all industries.
gdp_list_oecd <- sapply(all_countries_2010, function(country_code) {
  # Extract the table for the specific year and country
  country_table <- NATIOttl[TARGET_YEAR, country_code, , ]
  
  # Sum the Value Added row to get the country's total GDP
  # [cite_start]The sum is across all industry columns [cite: 6]
  sum(country_table[GDP_ROW_CODE, ], na.rm = TRUE)
})

gdp_list_oecd <- gdp_list_oecd * fx_rate_2010

# 4. Calculate Canadian and ROW GDP from the list
gdp_can_oecd <- gdp_list_oecd[TARGET_COUNTRY_EXCLUDE]
gdp_row_oecd <- sum(gdp_list_oecd[names(gdp_list_oecd) != TARGET_COUNTRY_EXCLUDE])
gdp_world_oecd <- sum(gdp_list_oecd)

cat("--- GDP Calculations (from OECD NATIOttl) ---\n")
cat("Canada GDP:", scales::dollar(gdp_can_oecd, scale = 1e-6, suffix = "T"), "\n")
cat("Rest of World (ROW) GDP:", scales::dollar(gdp_row_oecd, scale = 1e-6, suffix = "T"), "\n")
cat("World GDP:", scales::dollar(gdp_world_oecd, scale = 1e-6, suffix = "T"), "\n")

# 5. Construct the Final Omega Vector for the Model
# --- Calculate Omega (Real GDP Weights) ---
omega_data <- left_join(gdp_data, spatial_price_data, by = "Province") %>%
  mutate(RealGDP = gdp_value / (price_index / 100)) %>%
  mutate(omega = RealGDP / sum(RealGDP))

prov_gdp_shares <- setNames(omega_data$omega, omega_data$Province)

# Calculate each province's share of the WORLD total
# (Provincial Share of Canada) * (Canada's Share of World)
prov_world_shares <- prov_gdp_shares * (gdp_can_oecd / gdp_world_oecd)

# Calculate ROW's share of the world
row_world_share <- gdp_row_oecd / gdp_world_oecd

# Combine into the final vector and ensure the order is correct
omega_full_vec <- c(prov_world_shares, "ROW" = row_world_share)
omega_full_vec <- omega_full_vec[REGIONS] # REGIONS is your vector c(PROVINCES, "ROW")

cat("\n--- Final Omega Vector (Shares of World Income) ---\n")
print(round(omega_full_vec, 5))
cat("\nSum of Omega Vector:", sum(omega_full_vec), "\n")

# Phi (Value-Added Share)
phi_vec <- tapply(io_table_2010["VALU", industry_cols], industry_mapping$paper_sector[match(names(io_table_2010["VALU", industry_cols]), industry_mapping$oecd_code)], sum) /
  tapply(io_table_2010["OUTPUT", industry_cols], industry_mapping$paper_sector[match(names(io_table_2010["OUTPUT", industry_cols]), industry_mapping$oecd_code)], sum)

# Beta (Final Demand Share)
hfce_vec <- io_table_2010[industry_rows, "HFCE"]
names(hfce_vec) <- gsub("TTL_", "", names(hfce_vec))
agg_hfce <- tapply(hfce_vec, industry_mapping$paper_sector[match(names(hfce_vec), industry_mapping$oecd_code)], sum, na.rm = TRUE)
beta_vec <- agg_hfce / sum(agg_hfce, na.rm = TRUE)

# Gamma (Input-Output Matrix)
z_matrix <- io_table_2010[industry_rows, industry_cols]
rownames(z_matrix) <- gsub("TTL_", "", rownames(z_matrix))
row_map <- industry_mapping$paper_sector[match(rownames(z_matrix), industry_mapping$oecd_code)]
row_agg_z <- rowsum(z_matrix, group = row_map, reorder = TRUE, na.rm = TRUE)
col_map <- industry_mapping$paper_sector[match(colnames(row_agg_z), industry_mapping$oecd_code)]
agg_z_matrix <- t(rowsum(t(row_agg_z), group = col_map, reorder = TRUE, na.rm = TRUE))
gamma_matrix <- sweep(agg_z_matrix, 2, colSums(agg_z_matrix, na.rm=TRUE), FUN = "/")
gamma_matrix[is.na(gamma_matrix)] <- 0
gamma_matrix <- gamma_matrix[SECTORS, SECTORS] # Ensure order

# --- Create gamma_matrix based on direct transcription of Table 10 from the paper as a comparison ---
# Define the sector names in the precise order they appear in the paper's table
# This matches the order in your SECTORS variable.
# sector_names_ordered <- c(
#   "Agriculture, Mining", "Food, Textiles", "Wood", "Paper", "Chemicals, Rubber",
#   "Metals", "Equipment, Vehicles", "Manufacturing, n.e.c.", "Utilities", "Construction",
#   "Wholesale and Retail", "Hotels and Restaurants", "Transport", "Communication",
#   "Finance", "Real Estate", "Software", "Other Business Services", "Public Admin.",
#   "Education", "Health and Social", "Other Services"
# )
# 
# # Transcribe the data from Table 10 row by row.
# gamma_paper_data <- c(
#   0.297, 0.059, 0.002, 0.014, 0.119, 0.035, 0.072, 0.002, 0.034, 0.023, 0.096, 0.006, 0.041, 0.001, 0.092, 0.015, 0.028, 0.043, 0.007, 0.001, 0.001, 0.012,
#   0.326, 0.294, 0.001, 0.050, 0.067, 0.025, 0.013, 0.003, 0.014, 0.002, 0.066, 0.003, 0.036, 0.002, 0.026, 0.009, 0.010, 0.034, 0.005, 0.000, 0.001, 0.019,
#   0.429, 0.003, 0.189, 0.011, 0.063, 0.023, 0.022, 0.003, 0.027, 0.003, 0.099, 0.002, 0.062, 0.001, 0.025, 0.006, 0.006, 0.016, 0.002, 0.000, 0.000, 0.001,
#   0.060, 0.010, 0.056, 0.301, 0.094, 0.014, 0.028, 0.002, 0.060, 0.007, 0.082, 0.012, 0.071, 0.009, 0.044, 0.022, 0.030, 0.045, 0.008, 0.002, 0.001, 0.079,
#   0.446, 0.009, 0.002, 0.016, 0.317, 0.013, 0.013, 0.002, 0.022, 0.003, 0.045, 0.003, 0.031, 0.001, 0.020, 0.006, 0.011, 0.024, 0.005, 0.000, 0.001, 0.061,
#   0.189, 0.003, 0.003, 0.011, 0.046, 0.471, 0.034, 0.005, 0.036, 0.007, 0.081, 0.003, 0.037, 0.001, 0.026, 0.007, 0.006, 0.021, 0.004, 0.000, 0.000, 0.012,
#   0.005, 0.005, 0.002, 0.010, 0.058, 0.169, 0.538, 0.003, 0.007, 0.002, 0.063, 0.004, 0.022, 0.001, 0.020, 0.012, 0.017, 0.049, 0.003, 0.001, 0.001, 0.086,
#   0.048, 0.062, 0.114, 0.044, 0.132, 0.151, 0.036, 0.102, 0.015, 0.002, 0.139, 0.006, 0.025, 0.005, 0.031, 0.018, 0.016, 0.029, 0.005, 0.001, 0.000, 0.014,
#   0.379, 0.005, 0.001, 0.032, 0.074, 0.017, 0.066, 0.004, 0.002, 0.103, 0.040, 0.007, 0.042, 0.004, 0.077, 0.007, 0.045, 0.040, 0.037, 0.001, 0.001, 0.028,
#   0.097, 0.013, 0.075, 0.010, 0.105, 0.237, 0.091, 0.022, 0.002, 0.003, 0.112, 0.003, 0.030, 0.002, 0.037, 0.018, 0.016, 0.109, 0.007, 0.002, 0.000, 0.015,
#   0.020, 0.017, 0.066, 0.003, 0.055, 0.010, 0.020, 0.031, 0.005, 0.010, 0.069, 0.034, 0.061, 0.034, 0.181, 0.088, 0.052, 0.137, 0.021, 0.008, 0.003, 0.125,
#   0.042, 0.381, 0.001, 0.032, 0.021, 0.006, 0.010, 0.004, 0.027, 0.010, 0.113, 0.010, 0.019, 0.002, 0.095, 0.092, 0.018, 0.058, 0.014, 0.004, 0.001, 0.020,
#   0.013, 0.005, 0.207, 0.001, 0.012, 0.010, 0.053, 0.001, 0.013, 0.034, 0.083, 0.020, 0.323, 0.005, 0.072, 0.046, 0.010, 0.036, 0.016, 0.001, 0.001, 0.027,
#   0.025, 0.005, 0.002, 0.040, 0.075, 0.009, 0.024, 0.003, 0.006, 0.006, 0.142, 0.010, 0.295, 0.054, 0.078, 0.064, 0.043, 0.076, 0.008, 0.003, 0.001, 0.015,
#   0.010, 0.005, 0.001, 0.051, 0.022, 0.004, 0.013, 0.002, 0.012, 0.008, 0.049, 0.030, 0.031, 0.023, 0.386, 0.054, 0.076, 0.116, 0.015, 0.005, 0.003, 0.069,
#   0.036, 0.004, 0.001, 0.016, 0.024, 0.006, 0.017, 0.046, 0.002, 0.274, 0.044, 0.010, 0.018, 0.012, 0.290, 0.032, 0.015, 0.102, 0.018, 0.001, 0.001, 0.089,
#   0.009, 0.011, 0.002, 0.076, 0.061, 0.015, 0.051, 0.006, 0.004, 0.005, 0.077, 0.025, 0.038, 0.016, 0.058, 0.081, 0.230, 0.136, 0.013, 0.011, 0.002, 0.041,
#   0.008, 0.009, 0.002, 0.061, 0.068, 0.019, 0.059, 0.005, 0.010, 0.007, 0.097, 0.030, 0.037, 0.021, 0.079, 0.116, 0.098, 0.172, 0.017, 0.006, 0.002, 0.074,
#   0.016, 0.011, 0.082, 0.001, 0.026, 0.011, 0.041, 0.009, 0.021, 0.042, 0.081, 0.015, 0.031, 0.008, 0.025, 0.039, 0.040, 0.079, 0.065, 0.020, 0.271, 0.023,
#   0.045, 0.014, 0.001, 0.129, 0.062, 0.012, 0.043, 0.007, 0.073, 0.080, 0.087, 0.027, 0.128, 0.011, 0.018, 0.042, 0.034, 0.083, 0.024, 0.016, 0.002, 0.003,
#   0.016, 0.032, 0.001, 0.040, 0.113, 0.017, 0.075, 0.083, 0.038, 0.021, 0.126, 0.031, 0.018, 0.011, 0.045, 0.063, 0.016, 0.057, 0.016, 0.007, 0.100, 0.002,
#   0.012, 0.019, 0.001, 0.079, 0.061, 0.012, 0.086, 0.014, 0.028, 0.015, 0.125, 0.020, 0.027, 0.015, 0.069, 0.089, 0.041, 0.074, 0.023, 0.003, 0.002, 0.000
# )
# 
# # Create the matrix object
# gamma_matrix <- matrix(
#   gamma_paper_data,
#   nrow = 22,
#   ncol = 22,
#   byrow = TRUE,
#   dimnames = list(Producer = sector_names_ordered, User = sector_names_ordered)
# )
# 
# gamma_matrix <- t(gamma_matrix)

# Re-normalize the columns to ensure they are valid shares summing to 1
gamma_matrix <- sweep(gamma_matrix, 2, colSums(gamma_matrix), FUN = "/")

# Sanity check the new matrix
print("Column sums for the transcribed and corrected gamma_matrix (should all be 1.0):")
print(colSums(gamma_matrix))

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Part 2: Prepare Provincial and Trade Data
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Create the 3D 'pi' array: [destination, origin, sector]
pi_array <- array(0, dim = c(length(REGIONS), length(REGIONS), length(SECTORS)),
                  dimnames = list(dest = REGIONS, origin = REGIONS, sector = SECTORS))

# ** THE FIX: Populate the pi_array using the UNFILTERED 'shares' data frame **
# This ensures that trade with the Rest of World (ROW) is included in the model's initial state.
for (i in 1:nrow(shares)) {
  row <- shares[i, ]
  # Check that the row's regions and sector are part of our defined model components
  if (row$dest %in% REGIONS && row$origin %in% REGIONS && row$sector %in% SECTORS) {
    # We use pi_ni, which is the variable name for the trade share in the 'shares' data frame
    pi_array[row$dest, row$origin, row$sector] <- row$pi_ni
  }
}

# 1. Calculate ROW's total exports to Canada for each sector from your existing data
row_exports_to_can <- trade_flows_final %>%
  filter(origin == "ROW", dest %in% PROVINCES) %>%
  group_by(sector) %>%
  summarise(total_exports = sum(value, na.rm = TRUE))

# 1. Calculate ROW's total output for each sector (this part is unchanged and correct).
all_countries <- dimnames(NATIOttl)[[2]]
row_countries <- setdiff(all_countries, "CAN")
industry_codes_oecd <- dimnames(NATIOttl)[[4]]

row_output_list <- sapply(industry_codes_oecd, function(ind_code) {
  sum(NATIOttl["2010", row_countries, "OUTPUT", ind_code], na.rm = TRUE)
})

# --- REPLACE THE OLD row_output_df BLOCK WITH THIS ---
row_output_df <- tibble(
  oecd_code = names(row_output_list),
  total_output = row_output_list
) %>%
  left_join(industry_mapping, by = "oecd_code") %>%
  group_by(paper_sector) %>%
  summarise(total_output = sum(total_output, na.rm = TRUE)) %>%
  rename(sector = paper_sector) %>%
  # Convert the ROW output values from USD to CAD
  mutate(total_output = total_output * fx_rate_2010)

# 2. Calculate exports from each Canadian province to ROW.
can_exports_to_row <- trade_flows_final %>%
  filter(dest == "ROW", origin %in% PROVINCES) %>%
  select(origin, sector, value)

# 3. Calculate the correct pi_{ROW, Province} shares.
# The denominator is ROW's total output in that sector.
pi_row_dest_df <- can_exports_to_row %>%
  left_join(row_output_df, by = "sector") %>%
  # Ensure total_output is not zero to avoid division errors
  filter(total_output > 0) %>%
  mutate(pi_share = value / total_output) %>%
  select(origin, sector, pi_share)

# 4. Calculate the pi_{ROW,ROW} self-share for each sector.
pi_row_row_df <- pi_row_dest_df %>%
  group_by(sector) %>%
  summarise(sum_shares_to_can = sum(pi_share, na.rm = TRUE)) %>%
  mutate(pi_row_row = 1 - sum_shares_to_can)

# 5. Update the pi_array with the newly calculated, correct shares for dest="ROW".
# First, zero-out the existing (and incorrect) 'dest=ROW' slice.
pi_array["ROW", , ] <- 0

# Next, fill in the shares for ROW importing from Canadian provinces.
for (i in 1:nrow(pi_row_dest_df)) {
  orig <- pi_row_dest_df$origin[i]
  sec <- pi_row_dest_df$sector[i]
  share <- pi_row_dest_df$pi_share[i]
  if (sec %in% SECTORS) {
    pi_array["ROW", orig, sec] <- share
  }
}

# Finally, fill in the ROW self-share (the diagonal element).
for (i in 1:nrow(pi_row_row_df)) {
  sec <- pi_row_row_df$sector[i]
  share <- pi_row_row_df$pi_row_row[i]
  if (sec %in% SECTORS) {
    pi_array["ROW", "ROW", sec] <- share
  }
}

# Sanity check: ensure shares for each destination sum to 1
# This might show small rounding errors, which is acceptable.
print("Checking if pi_array slices sum to 1:")
print(apply(pi_array, c("dest", "sector"), sum))

# Create the theta vector
theta_vec <- sector_to_theta %>%
  distinct(sector, theta) %>%
  tibble::deframe() %>%
  .[SECTORS]

# Display a sample of the prepared data
print(kable(omega_data), caption = "Calculated Real GDP Weights (omega)")
cat("\nTheta Vector:\n")
print(theta_vec)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Part 1: The Corrected Model Solver (Final Version with Stability Fixes)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

dump_solver_state <- function(iteration_number, experiment_name, ...) {
  # Capture the list of objects to save
  objects_to_save <- list(...)
  
  # Create a descriptive filename
  filename <- paste0("solver_state_", 
                     gsub("[: ,]", "_", experiment_name), # Sanitize experiment name for filename
                     "_iter_", 
                     iteration_number, 
                     ".rds")
  
  # Save the list of objects to an RDS file
  saveRDS(objects_to_save, file = filename)
  
  # Print a confirmation message to the console
  cat(paste("\n*** Solver state dumped to:", filename, "***\n"))
}

solve_model_final <- function(tau_hat_array, pi_array, gamma_matrix, phi_vec, theta_vec, beta_vec, omega_vec, experiment_name, max_iter = 5000, tolerance = 1e-9) {
  
  region_names <- dimnames(pi_array)[[1]]
  sector_names <- dimnames(pi_array)[[3]]
  num_regions <- length(region_names)
  num_sectors <- length(sector_names)
  
  w_hat <- rep(1, num_regions)
  names(w_hat) <- region_names
  p_hat <- matrix(1, nrow = num_regions, ncol = num_sectors, dimnames = list(region_names, sector_names))
  initial_income <- setNames(omega_vec, region_names)
  
  cat("Starting corrected & optimized iterative solver...\n")
  
  for (iter in 1:max_iter) {
    w_hat_old <- w_hat
    
    # Inner loop to find p_hat for a given w_hat
    for (p_iter in 1:100) { 
      p_hat_old_inner <- p_hat
      term1_log_wages <- log(w_hat) %o% phi_vec
      term2_log_prices_sum <- log(p_hat) %*% gamma_matrix
      term2_full <- sweep(term2_log_prices_sum, 2, (1 - phi_vec), "*")
      c_hat <- exp(term1_log_wages + term2_full)
      
      p_hat_numerator_terms <- array(0, dim=dim(pi_array), dimnames=dimnames(pi_array))
      for (s in sector_names) {
        # Construct a matrix where each column is the vector of cost changes.
        # This is the same as the original code.
        c_hat_mat_s <- matrix(c_hat[,s], nrow=num_regions, ncol=num_regions, byrow=FALSE)
        
        # THE FIX: Transpose the cost matrix 'c_hat_mat_s'.
        # This ensures that for a trade flow from source 'i' to destination 'n',
        # we use the cost from the source, c_hat[i,s].
        cost_shock_term <- (tau_hat_array[,,s] * t(c_hat_mat_s))^(-theta_vec[s])
        
        # The rest of the calculation remains the same.
        p_hat_numerator_terms[,,s] <- pi_array[,,s] * cost_shock_term
      }

      p_hat_sum_term <- apply(p_hat_numerator_terms, c("dest", "sector"), sum, na.rm = TRUE)
      theta_matrix <- matrix(theta_vec, nrow=num_regions, ncol=num_sectors, byrow=TRUE)
      p_hat_new <- p_hat_sum_term^(-1 / theta_matrix)
      p_hat_new[is.infinite(p_hat_new) | is.na(p_hat_new)] <- 1
      
      if (max(abs(p_hat_new - p_hat_old_inner), na.rm=TRUE) < 1e-10) break
      p_hat <- p_hat_new
    }
    
    # Wage Update Mechanism
    # ** THE FIX: Manually create the denominator array to avoid broadcasting issues **
    # First, create an empty array with the correct dimensions
    p_hat_sum_array <- array(0, dim = dim(p_hat_numerator_terms), dimnames = dimnames(p_hat_numerator_terms))
    # Then, loop through each origin and fill the slice with the correct denominator
    for (o_idx in 1:dim(p_hat_sum_array)[2]) {
      p_hat_sum_array[, o_idx, ] <- p_hat_sum_term
    }
    
    pi_prime <- p_hat_numerator_terms / p_hat_sum_array
    pi_prime[is.na(pi_prime)] <- 0
    
    I_prime <- w_hat * initial_income
    Xf_prime <- I_prime %o% beta_vec[sector_names]
    X_prime <- Xf_prime 
    
    for (i in 1:50) {
      R_prime_list <- vapply(sector_names, function(j) t(pi_prime[,,j]) %*% X_prime[,j], FUN.VALUE = numeric(num_regions))
      R_prime <- matrix(R_prime_list, nrow = num_regions, dimnames = list(region_names, sector_names))
      R_prime[is.na(R_prime) | is.infinite(R_prime)] <- 0
      
      Xi_prime <- (R_prime %*% diag(1 - phi_vec[sector_names])) %*% t(gamma_matrix[sector_names, sector_names])
      Xi_prime[is.na(Xi_prime) | is.infinite(Xi_prime)] <- 0
      
      X_prime_new <- Xf_prime + Xi_prime
      if(max(abs(X_prime_new - X_prime), na.rm = TRUE) < 1e-10) break
      X_prime <- X_prime_new
    }
    
    # In equilibrium, total expenditure equals total revenue. R_prime holds the final revenue values.
    # The paper's equation (10) defines income as the value-added portion of revenue: I_n = sum(phi_j * R_nj).
    # We must calculate this generated income to update wages correctly.
    
    # Step 1: Calculate the generated income (Value Added) from the counterfactual revenues (R_prime).
    # We multiply the revenue in each region-sector by its value-added share (phi_vec) and sum across sectors for each region.
    Generated_VA_prime <- rowSums(R_prime * matrix(phi_vec, nrow=num_regions, ncol=num_sectors, byrow=TRUE))
    
    # Step 2: Calculate the update ratio using the correct generated income.
    update_ratio <- Generated_VA_prime / I_prime
    
    # *** FINAL STABILITY FIX: Clip the update ratio to prevent extreme jumps ***
    w_hat_new <- w_hat * update_ratio
    
    w_hat_new[is.na(w_hat_new) | is.infinite(w_hat_new)] <- 1
    
    w_hat_new <- w_hat_new / sum(w_hat_new * omega_vec, na.rm = TRUE)
    
    # Use a small, but not extreme, dampening factor
    w_hat <- 0.1 * w_hat_new + 0.9 * w_hat_old
    
    if (iter == 1) {
      dump_solver_state(iter, experiment_name,
                        w_hat = w_hat,
                        p_hat = p_hat,
                        c_hat = c_hat,
                        pi_prime = pi_prime,
                        R_prime = R_prime,
                        X_prime = X_prime,
                        Generated_VA_prime = Generated_VA_prime,
                        update_ratio = update_ratio,
                        I_prime = I_prime)
    }
    
    if (max(abs(w_hat - w_hat_old), na.rm=TRUE) < tolerance) {
      cat("Converged after", iter, "iterations.\n")
      return(list(w_hat = w_hat, p_hat = p_hat))
    }
  }
  
  warning("Solver did not converge after ", max_iter, " iterations.")
  return(list(w_hat = w_hat, p_hat = p_hat))
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Part 2: Helper Function to Run and Display Experiments (Corrected)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

run_experiment <- function(tau_hat_input, experiment_name, solver_args_list) {
  cat(paste("\n--- Running Experiment:", experiment_name, "---\n"))
  
  # 1. Combine the experiment-specific tau_hat_array with the list of common solver arguments.
  all_args_for_solver <- c(list(tau_hat_array = tau_hat_input, experiment_name = experiment_name), solver_args_list)
  
  # 2. Use do.call() to execute the solver. This correctly passes the list of arguments.
  #    NOTE: This assumes you are still using the 'solve_model_final' function from the previous step.
  solution <- do.call(solve_model_final, all_args_for_solver)
  
  # --- The rest of the function is for calculating and displaying welfare ---
  log_p_hat <- log(solution$p_hat)
  log_p_hat[is.infinite(log_p_hat) | is.na(log_p_hat)] <- 0
  
  # Ensure beta_vec is ordered correctly
  beta_vec_ordered <- solver_args_list$beta_vec[colnames(solution$p_hat)]
  
  log_price_level_change <- log_p_hat %*% beta_vec_ordered
  price_level_change <- as.vector(exp(log_price_level_change))
  
  u_hat <- solution$w_hat / price_level_change
  welfare_change_pct <- (u_hat[PROVINCES] - 1) * 100
  
  # Ensure omega_data is ordered correctly for the final aggregation
  omega_ordered <- omega_data[match(PROVINCES, omega_data$Province),]
  agg_welfare_change <- sum(welfare_change_pct * omega_ordered$omega, na.rm = TRUE)
  
  results_df <- data.frame(
    Province = names(welfare_change_pct),
    `Welfare Change (%)` = welfare_change_pct,
    check.names = FALSE
  )
  
  cat(paste("\n## Results:", experiment_name, "\n"))
  print(knitr::kable(results_df, digits = 2, caption = "Provincial Welfare Gains (%)"))
  cat("\nAggregate Canadian Welfare Gain (%):", format(agg_welfare_change, digits = 2), "\n")
  
  return(invisible(results_df))
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Part 3: Replicating Tables 5 and 6 (with Corrected Function Calls)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# --- Setup for experiments ---
# This list contains all the arguments that are COMMON to every solver run
solver_args <- list(pi_array = pi_array, gamma_matrix = gamma_matrix, phi_vec = phi_vec,
                    theta_vec = theta_vec, beta_vec = beta_vec, omega_vec = omega_full_vec)

# --- Table 5 Experiments ---
# T5, Col 4: 10% Lower Internal tau
tau_t5_c4 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
is_interprovincial_2d <- outer(dimnames(tau_t5_c4)[[1]], dimnames(tau_t5_c4)[[2]], 
                               FUN = function(d, o) d %in% PROVINCES & o %in% PROVINCES & d != o)
logical_index_3d_interprov <- array(rep(is_interprovincial_2d, dim(tau_t5_c4)[3]), dim = dim(tau_t5_c4))
tau_t5_c4[logical_index_3d_interprov] <- 0.9
run_experiment(tau_t5_c4, "Table 5, Col 4: 10% Lower Internal tau", solver_args)

# T5, Col 5: 10% Lower External tau
tau_t5_c5 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
is_international_2d <- outer(dimnames(tau_t5_c5)[[1]], dimnames(tau_t5_c5)[[2]],
                             FUN = function(d, o) (d == "ROW" & o != "ROW") | (o == "ROW" & d != "ROW"))
logical_index_3d_intl <- array(rep(is_international_2d, dim(tau_t5_c5)[3]), dim = dim(tau_t5_c5))
tau_t5_c5[logical_index_3d_intl] <- 0.9
run_experiment(tau_t5_c5, "Table 5, Col 5: 10% Lower External tau", solver_args)

# --- Table 6 Experiments ---
cat("\n--- Estimating Cost Components for Table 6 ---\n")

# Gravity Model 1: On trade COSTS (tau_bar) to get Non-Geographic component
# This is the regression you asked to verify.
shares_dist <- shares_dist %>% mutate(log_tau = log(tau_bar))
cost_gravity_mod <- feols(log_tau ~ log(distance) | origin + dest, data = shares_dist)
shares_dist$tau_geo <- exp(predict(cost_gravity_mod))
shares_dist$tau_NG <- shares_dist$tau_bar / shares_dist$tau_geo

# Gravity Model 2: On trade FLOWS to get Asymmetric component
shares_dist <- shares_dist %>% mutate(log_flow_norm = log(pi_ni / pi_nn))
flow_gravity_mod <- feols(log_flow_norm ~ log(distance) | origin + dest, data = shares_dist)
fixed_effects <- fixef(flow_gravity_mod)
t_i_log <- -(fixed_effects$origin[PROVINCES] + fixed_effects$dest[PROVINCES])
t_i_log_normalized <- t_i_log - t_i_log["AB"] # Normalize relative to Alberta
shares_dist$t_i_log <- t_i_log_normalized[shares_dist$origin]
shares_dist$t_n_log <- t_i_log_normalized[shares_dist$dest]

### --- FINAL REFINED REPLICATION OF TABLE 6 ---

# Initialize an empty data frame to store the results
non_distance_cost_results_final <- data.frame()

# Get a list of sectors to loop over
sectors_to_regress <- unique(shares_dist$sector)

for (s in sectors_to_regress) {
  
  sector_data <- shares_dist %>% filter(sector == s)
  
  # Create the normalized distance variable
  sector_data <- sector_data %>% 
    mutate(dist_norm = distance / sqrt(d_nn_o * d_nn_d))
  
  # Run the cost gravity model
  cost_mod_s <- feols(log(tau_bar) ~ log(dist_norm) | origin + dest, data = sector_data)
  
  # Calculate the purely geographic component of cost
  dist_coefficient <- coef(cost_mod_s)["log(dist_norm)"]
  sector_data$tau_geo <- exp(dist_coefficient * log(sector_data$dist_norm))
  
  # Calculate the non-geographic residual factor
  sector_data$tau_NG <- sector_data$tau_bar / sector_data$tau_geo
  
  # *** THE FINAL FIX: Calculate tau_hat to only ever REDUCE costs ***
  # This implements your interpretation of the paper's note.
  # We take the minimum of 1 and the calculated shock, so tau_hat is never > 1.
  sector_data$tau_hat_nd <- pmin(1, 1 / sector_data$tau_NG)
  
  non_distance_cost_results_final <- rbind(non_distance_cost_results_final, sector_data)
}

# T6, Col 1: 10% Lower Measured Internal Costs
tau_t6_c1 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (i in 1:nrow(full_data)) {
  row <- full_data[i, ]
  if (row$origin %in% PROVINCES && row$dest %in% PROVINCES && row$origin != row$dest && !is.na(row$tau_bar) && row$tau_bar > 1) {
    tau_hat <- (1 + 0.9 * (row$tau_bar - 1)) / row$tau_bar
    tau_t6_c1[row$dest, row$origin, row$sector] <- tau_hat
  }
}
# Corrected Call to run_experiment
run_experiment(tau_t6_c1, "Table 6, Col 1: 10% Lower Measured Internal Costs", solver_args)

# T6, Col 4: Eliminate Non-Distance Internal Costs
tau_t6_c4_final <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (i in 1:nrow(non_distance_cost_results_final)) {
  row <- non_distance_cost_results_final[i, ]
  if (!is.na(row$tau_hat_nd)) {
    tau_t6_c4_final[row$dest, row$origin, row$sector] <- row$tau_hat_nd
  }
}
run_experiment(tau_t6_c4_final, "Table 6, Col 4 (Final Version)", solver_args)

# T6, Col 5: Eliminate All Internal Costs
tau_t6_c5 <- array(1, dim = dim(pi_array), dimnames = dimnames(pi_array))
for (i in 1:nrow(full_data)) {
  row <- full_data[i, ]
  if (row$origin %in% PROVINCES && row$dest %in% PROVINCES && row$origin != row$dest && !is.na(row$tau_bar) && row$tau_bar > 0) {
    tau_t6_c5[row$dest, row$origin, row$sector] <- 1 / row$tau_bar
  }
}
# Corrected Call to run_experiment
run_experiment(tau_t6_c5, "Table 6, Col 5: Eliminate All Internal Costs", solver_args)