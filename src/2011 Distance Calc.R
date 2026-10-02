library(dplyr)
library(geosphere)
library(tidyr)
library(readr)

da_raw <- read.csv("data/distance/2011_92-151_XBB.csv", stringsAsFactors=TRUE)

names(da_raw) <- toupper(names(da_raw))

da_subset <- da_raw %>%
  select(PRNAME, DALAT, DALONG, DBPOP2011) %>%
  filter(!is.na(DBPOP2011))

# Convert values to numeric just in case
da_subset <- da_subset %>%
  mutate(
    DBPOP2011 = as.numeric(DBPOP2011),
    DALAT = as.numeric(DALAT),
    DALONG = as.numeric(DALONG)
  ) %>%
  filter(!is.na(DALAT) & !is.na(DALONG) & !is.na(DBPOP2011))

# Compute population-weighted mean coordinates
province_centres <- da_subset %>%
  group_by(PRNAME) %>%
  summarise(
    lat = sum(DALAT * DBPOP2011, na.rm = TRUE) / sum(DBPOP2011, na.rm = TRUE),
    lon = sum(DALONG * DBPOP2011, na.rm = TRUE) / sum(DBPOP2011, na.rm = TRUE),
    .groups = "drop"
  )

# Province name-to-code mapping
province_codes <- c(
  "Newfoundland and Labrador" = "NL",
  "Prince Edward Island" = "PE",
  "Nova Scotia" = "NS",
  "New Brunswick" = "NB",
  "Quebec" = "QC",
  "Ontario" = "ON",
  "Manitoba" = "MB",
  "Saskatchewan" = "SK",
  "Alberta" = "AB",
  "British Columbia" = "BC"
)
View(province_centres)

# Subset and rename
da_data <- da_raw %>%
  select(PRUID, lat = DALAT, lon = DALONG, Population = DBPOP2011) %>%
  mutate(
    prov = case_when(
      PRUID == "10" ~ "NL",
      PRUID == "11" ~ "PE",
      PRUID == "12" ~ "NS",
      PRUID == "13" ~ "NB",
      PRUID == "24" ~ "QC",
      PRUID == "35" ~ "ON",
      PRUID == "46" ~ "MB",
      PRUID == "47" ~ "SK",
      PRUID == "48" ~ "AB",
      PRUID == "59" ~ "BC",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(prov), !is.na(Population))

da_data <- da_data %>%
  mutate(
    Population = as.numeric(Population),
    lat = as.numeric(lat),
    lon = as.numeric(lon)
  ) %>%
  filter(!is.na(lat) & !is.na(lon) & !is.na(Population))

# Calculate population-weighted provincial centroids
prov_centroids <- da_data %>%
  group_by(prov) %>%
  summarise(
    lon = weighted.mean(lon, Population, na.rm = TRUE),
    lat = weighted.mean(lat, Population, na.rm = TRUE)
  )

# Calculate within-province distances (d_nn)
# This is the population-weighted average distance from each DA to its provincial centroid.
d_nn_calc <- da_data %>%
  left_join(prov_centroids, by = "prov", suffix = c("_da", "_prov")) %>%
  mutate(
    dist_to_centroid = distHaversine(cbind(lon_da, lat_da), cbind(lon_prov, lat_prov)) / 1000
  ) %>%
  group_by(prov) %>%
  summarise(
    d_nn = weighted.mean(dist_to_centroid, Population, na.rm = TRUE)
  )

# Create the final distance matrix
provs <- unique(da_data$prov)

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
  ) %>%
  # Calculate the final normalized distance used in regressions
  mutate(d_norm = distance / sqrt(d_nn_o * d_nn_d)) %>%
  select(origin, dest, d_norm)

write_csv(dist_mat, "2011_dist_mat.csv")
