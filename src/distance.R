# Geographic distances between and within regions.
#
# Provinces and territories are located at their population-weighted
# centroids, computed from census dissemination-block populations and the
# representative points of the dissemination areas that contain them (census
# Geographic Attribute Files, catalogue 92-151-X). Internal distance d_nn is the
# population-weighted mean distance from the dissemination areas to the
# provincial centroid. Normalized distance is d_ni / sqrt(d_nn * d_ii)
# (Albrecht and Tombe, 2016).

#' Read dissemination-area representative points with dissemination-block
#' populations from a census Geographic Attribute File, or from the compact
#' extract stored in data/raw/census.
#'
#' Columns are read as character and converted explicitly. (The legacy scripts
#' used read.csv(stringsAsFactors = TRUE) followed by as.numeric(), which turns
#' a factor into its level codes; the committed 2011 distance matrix was
#' computed with those codes in place of populations.) Provinces are identified
#' by their numeric code (PRUID) rather than by name, because names differ
#' across census vintages (e.g. "Yukon Territory" vs "Yukon").
#'
#' @return Tibble: region, lat, lon, population (one row per dissemination block).
read_da_points <- function(path) {
  if (!file.exists(path)) stopf("Census file not found: %s", path)
  dt <- data.table::fread(path, colClasses = "character", encoding = "Latin-1",
                          showProgress = FALSE)
  names(dt) <- toupper(sub("^﻿", "", names(dt)))
  pick <- function(candidates, pattern = NULL) {
    hit <- intersect(candidates, names(dt))
    if (length(hit) == 0 && !is.null(pattern)) hit <- grep(pattern, names(dt), value = TRUE)
    if (length(hit) == 0) stopf("Cannot find any of %s in %s", paste(candidates, collapse = "/"), path)
    hit[1]
  }
  regions <- load_regions() |> filter(!is.na(pruid))

  if ("PROV" %in% names(dt)) {
    # Compact extract written by the legacy 2021 script (region codes already assigned).
    region <- dt[["PROV"]]
  } else {
    pruid <- dt[[pick(c("PRUID_PRIDU", "PRUID"))]]
    region <- regions$region_id[match(as.integer(pruid), as.integer(regions$pruid))]
  }
  num <- function(x) suppressWarnings(as.numeric(x))  # non-numeric entries (e.g. "..") become NA
  out <- tibble(
    region = region,
    lat = num(dt[[pick(c("LAT", "DARPLAT_ADLAT", "DARPLAT", "DALAT"))]]),
    lon = num(dt[[pick(c("LON", "DARPLONG_ADLONG", "DARPLONG", "DALONG"))]]),
    population = num(dt[[pick(c("POPULATION"), pattern = "^DBPOP[0-9]{4}")]])
  )
  keep <- !is.na(out$region) & !is.na(out$lat) & !is.na(out$lon) & !is.na(out$population)
  if (any(!keep & !is.na(out$region))) {
    log_info(sprintf("Dropped %d census records with missing coordinates or population.",
                     sum(!keep & !is.na(out$region))))
  }
  out[keep, ]
}

#' Population-weighted centroids and internal distances.
region_geography <- function(da) {
  centroids <- da |>
    group_by(region) |>
    summarise(lat = stats::weighted.mean(lat, population),
              lon = stats::weighted.mean(lon, population),
              population = sum(population), .groups = "drop")
  internal <- da |>
    inner_join(centroids |> select(region, c_lat = lat, c_lon = lon), by = "region") |>
    mutate(d = haversine_km(lon, lat, c_lon, c_lat)) |>
    group_by(region) |>
    summarise(d_internal = stats::weighted.mean(d, population), .groups = "drop")
  centroids |> inner_join(internal, by = "region")
}

#' Representative locations and internal distances of the foreign regions.
#'
#' Only used when the gravity sample includes international pairs. The United
#' States is placed at the 2000 US Census mean centre of population (near Edgar
#' Springs, Missouri) and the rest of the world at Almaty, Kazakhstan (the
#' legacy choice, close to the population centroid of the world outside North
#' America). Internal distances use the Head and Mayer (2002) disc formula
#' (2/3) * sqrt(area / pi) with land areas (km^2).
foreign_geography <- function() {
  us_land <- 9147593
  world_land <- 148940000
  canada_land <- 8965121
  tibble(
    region = c("USA", "ROW"),
    lat = c(37.696987, 43.238949),
    lon = c(-91.809567, 76.889709),
    population = NA_real_,
    d_internal = (2 / 3) * sqrt(c(us_land, world_land - us_land - canada_land) / pi)
  )
}

#' Bilateral distance matrix in long form.
#'
#' @param geo Output of region_geography() (optionally bound with foreign_geography()).
#' @return Tibble: origin, dest, distance_km (internal distance on the
#'   diagonal), d_internal_origin, d_internal_dest, distance_normalized, adjacent.
distance_matrix <- function(geo) {
  adjacent <- adjacency_function()
  tidyr::expand_grid(origin = geo$region, dest = geo$region) |>
    left_join(geo |> select(origin = region, lat_o = lat, lon_o = lon, d_internal_origin = d_internal),
              by = "origin") |>
    left_join(geo |> select(dest = region, lat_d = lat, lon_d = lon, d_internal_dest = d_internal),
              by = "dest") |>
    mutate(
      distance_km = if_else(origin == dest, d_internal_origin,
                            haversine_km(lon_o, lat_o, lon_d, lat_d)),
      distance_normalized = distance_km / sqrt(d_internal_origin * d_internal_dest),
      adjacent = adjacent(origin, dest)
    ) |>
    select(origin, dest, distance_km, d_internal_origin, d_internal_dest,
           distance_normalized, adjacent)
}

#' Build and save the distance matrix used by a configuration.
build_distances <- function(cfg) {
  da <- read_da_points(cfg$paths$census_da)
  geo <- region_geography(da)
  missing <- setdiff(cfg$regions$domestic, geo$region)
  if (length(missing) > 0) {
    warnf(paste0("No census points for %s in %s; distances involving these regions are ",
                 "missing and their pairs drop out of the gravity regressions."),
          paste(missing, collapse = ", "), cfg$paths$census_da)
  }
  geo <- bind_rows(geo, foreign_geography())
  out <- distance_matrix(geo)
  write_table(out, cfg$paths$distances)
  write_table(geo, sub("\\.csv$", "_centroids.csv", cfg$paths$distances))
  out
}

#' Load distances for a configuration (legacy format supported for replication).
load_distances <- function(cfg) {
  path <- cfg$paths$distances
  if (!file.exists(path)) stopf("Distance file %s not found; run scripts/02_build_distances.R.", path)
  d <- readr::read_csv(path, show_col_types = FALSE)
  if (!"distance_normalized" %in% names(d) && "d_norm" %in% names(d)) {
    # Legacy matrices (origin, dest, d_norm) only carry normalized distances.
    d <- d |> mutate(distance_normalized = d_norm, distance_km = NA_real_)
  }
  if (!"adjacent" %in% names(d)) {
    adjacent <- adjacency_function()
    d <- d |> mutate(adjacent = adjacent(origin, dest))
  }
  d
}
