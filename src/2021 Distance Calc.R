# 2021 Distance calculation
## Load the Dissemination Area data from 2021
da_raw <- read.csv("data/distance/2021_92-151_X.csv", stringsAsFactors=TRUE)

names(da_raw) <- toupper(names(da_raw))

## Definitions
provs <- c("AB","BC","MB","NB","NL","NS","ON","PE","QC","SK")
provsplus <- c("AB","BC","MB","NB","NL","NS","ON","PE","QC","SK","YT","NT","NU")
provinces <- c("Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia", "New Brunswick", "Quebec", 
               "Ontario", "Manitoba", "Saskatchewan", "Alberta", "British Columbia")
provincesplus <- c("Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia", "New Brunswick", "Quebec", 
                   "Ontario", "Manitoba", "Saskatchewan", "Alberta", "British Columbia", 
                   "Yukon", "Northwest Territories", "Nunavut")

## Clean and prepare the data
da_data <- da_raw %>%
  select(PRENAME_PRANOM, lat = DARPLAT_ADLAT, lon = DARPLONG_ADLONG, Population = DBPOP2021_IDPOP2021) %>%
  mutate(
    prov = recode(PRENAME_PRANOM,
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
                  "Yukon Territory"="YT",
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

write_csv(da_data, "2021_da_data.csv")
da_data <- read_csv("2021_da_data.csv")

## Calculate population-weighted provincial centroids
prov_centroids <- da_data %>%
  group_by(prov) %>%
  summarise(
    lon = weighted.mean(lon, Population, na.rm = TRUE),
    lat = weighted.mean(lat, Population, na.rm = TRUE)
  )

almaty_coords <- tribble(
  ~prov, ~lat, ~lon,
  "ROW", 43.238949, 76.889709)

us_centroid <- tribble(
  ~prov, ~lon, ~lat,
  "USA", -91.809567, 37.696987)

## Calculate within-province distances (d_nn)
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

## Create the final distance matrix for Canada
dist_mat <- expand_grid(origin = provsplus, dest = provsplus) %>%
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

## U.S. Data
us_capitals <- data.frame(
  state = c("California", "Illinois", "New York"),
  capital = c("Sacramento", "Springfield", "Albany"),
  lat = c(38.555605, 39.783250, 42.7335),
  lon = c(-121.468926, -89.650373, -73.781339)
)

closest_us_capital <- prov_centroids %>%
  rowwise() %>%
  mutate(
    closest_capital = us_capitals$capital[which.min(distHaversine(c(lon, lat), cbind(us_capitals$lon, us_capitals$lat)))],
    capital_lat = us_capitals$lat[us_capitals$capital == closest_capital],
    capital_lon = us_capitals$lon[us_capitals$capital == closest_capital]
  )

dist_to_us <- closest_us_capital %>%
  mutate(
    distance_to_us = distHaversine(cbind(lon, lat), cbind(capital_lon, capital_lat)) / 1000
  ) %>%
  select(prov, distance_to_us)

us_land_area_sq_km <- 9525067
d_nn_us <- (2/3) * sqrt(us_land_area_sq_km / pi)

## Create US-Canada and Canada-US distance matrices
### US to Canada
dist_us_can <- dist_to_us %>%
  rename(dest = prov, distance = distance_to_us) %>%
  mutate(origin = "USA") %>%
  left_join(d_nn_calc, by = c("dest" = "prov")) %>%
  rename(d_nn_d = d_nn) %>%
  mutate(d_nn_o = d_nn_us)

### Canada to US
dist_can_us <- dist_to_us %>%
  rename(origin = prov, distance = distance_to_us) %>%
  mutate(dest = "USA") %>%
  left_join(d_nn_calc, by = c("origin" = "prov")) %>%
  rename(d_nn_o = d_nn) %>%
  mutate(d_nn_d = d_nn_us)

### US internal distance
dist_us_us <- data.frame(origin = "USA", dest = "USA", distance = d_nn_us, d_nn_o = d_nn_us, d_nn_d = d_nn_us)

## Add ROW (Almaty, Kazakhstan)
row_land_area_sq_km <- 490562263 # total area sub US and CAN 
d_nn_row <- (2/3) * sqrt(row_land_area_sq_km / pi)
dist_row_row <- data.frame(origin = "ROW", dest = "ROW", distance = d_nn_row, d_nn_o = d_nn_row, d_nn_d = d_nn_row)

dist_can_row <- prov_centroids %>%
  ungroup() %>%
  mutate(
    distance = distHaversine(cbind(lon, lat), c(almaty_coords$lon, almaty_coords$lat)) / 1000
  ) %>%
  select(origin = prov, distance) %>%
  mutate(dest = "ROW") %>%
  left_join(d_nn_calc, by = c("origin" = "prov")) %>%
  rename(d_nn_o = d_nn) %>%
  mutate(d_nn_d = d_nn_row)

dist_row_can <- dist_can_row %>%
  rename(dest = origin, origin = dest) %>%
  mutate(d_nn_o = d_nn_row, d_nn_d = d_nn_o) %>%
  select(origin, dest, distance, d_nn_o, d_nn_d)

dist_us_row_val <- distHaversine(c(us_centroid$lon, us_centroid$lat), c(almaty_coords$lon, almaty_coords$lat)) / 1000

dist_us_row <- data.frame(origin = "USA", dest = "ROW", distance = dist_us_row_val, d_nn_o = d_nn_us, d_nn_d = d_nn_row)
dist_row_us <- data.frame(origin = "ROW", dest = "USA", distance = dist_us_row_val, d_nn_o = d_nn_row, d_nn_d = d_nn_us)

## Append all matrices
dist_mat_final <- bind_rows(dist_mat, dist_us_can, dist_can_us, dist_us_us, dist_can_row, dist_row_can, dist_us_row, dist_row_us, dist_row_row)

write_csv(dist_mat_final, "dist_mat_final.csv")