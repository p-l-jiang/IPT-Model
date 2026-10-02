# Download (or verify) the source data for a configuration.
#
# Usage: Rscript scripts/01_download_data.R [--config config/default.yml]
#
# Statistics Canada tables are downloaded once and cached in
# data/raw/statcan/ (git-ignored); compact extracts are cached next to them.
# The OECD ICIO tables are not downloaded automatically: the CSV for each
# required year must be present at the path given by paths$icio_file.

source("src/load.R")
cfg <- script_config()

invisible(read_trade_flows_detail(cfg))
invisible(read_us_trade_shares_source(cfg))
invisible(read_population(cfg))
invisible(read_spatial_prices(cfg))
invisible(read_sut(cfg, cfg$years$target))

icio_years <- cfg$years$target
if (identical(cfg$trade_costs$sample, "all")) icio_years <- panel_years(cfg)
missing <- icio_years[!file.exists(vapply(icio_years, function(y) icio_path(cfg, y), ""))]
if (length(missing) > 0) {
  stopf("Missing ICIO tables for %s (expected at %s). Download them from https://oe.cd/icio.",
        paste(missing, collapse = ", "), cfg$paths$icio_file)
}
log_info("All source data are available.")
