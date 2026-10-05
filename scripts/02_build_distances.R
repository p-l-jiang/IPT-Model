# Build the distance matrix (population-weighted centroids, internal and
# normalized distances, adjacency) from census dissemination-area data.
#
# Usage: Rscript scripts/02_build_distances.R [--config config/default.yml]

source("src/load.R")
cfg <- script_config()
if (is.null(cfg$paths$census_da)) {
  log_info("This configuration uses the pre-built distance file ", cfg$paths$distances, "; nothing to do.")
} else if (!file.exists(cfg$paths$census_da) && file.exists(cfg$paths$distances)) {
  # The raw census file is large and not committed; the distances built from it are.
  log_info("Census file ", cfg$paths$census_da, " not found; using the committed distances in ",
           cfg$paths$distances, " (see data/README.md to rebuild them).")
} else {
  if (!file.exists(cfg$paths$census_da)) stopf("Census file %s not found.", cfg$paths$census_da)
  d <- build_distances(cfg)
  log_info(sprintf("Wrote %s (%d pairs).", cfg$paths$distances, nrow(d)))
}
