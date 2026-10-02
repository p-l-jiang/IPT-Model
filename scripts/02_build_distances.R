# Build the distance matrix (population-weighted centroids, internal and
# normalized distances, adjacency) from census dissemination-area data.
#
# Usage: Rscript scripts/02_build_distances.R [--config config/default.yml]

source("src/load.R")
cfg <- script_config()
if (is.null(cfg$paths$census_da)) {
  log_info("This configuration uses the pre-built distance file ", cfg$paths$distances, "; nothing to do.")
} else {
  if (!file.exists(cfg$paths$census_da)) stopf("Census file %s not found.", cfg$paths$census_da)
  d <- build_distances(cfg)
  log_info(sprintf("Wrote %s (%d pairs).", cfg$paths$distances, nrow(d)))
}
