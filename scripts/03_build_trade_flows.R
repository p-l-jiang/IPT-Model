# Build the bilateral trade-flow panel (CAD millions) and the US/ROW split.
#
# Usage: Rscript scripts/03_build_trade_flows.R [--config config/default.yml]

source("src/load.R")
cfg <- script_config()
years <- panel_years(cfg)
icio_years <- cfg$years$target
if (identical(cfg$trade_costs$sample, "all")) {
  icio_years <- years[file.exists(vapply(years, function(y) icio_path(cfg, y), ""))]
}
panel <- build_flow_panel(cfg, years, icio_years)
readr::write_csv(panel, processed_path(cfg, "trade_flows.csv.gz"))

if ("USA" %in% cfg$regions$foreign) {
  shares <- us_trade_shares(cfg, years)
  write_table(shares, processed_path(cfg, "us_trade_shares.csv"))
}
log_info(sprintf("Wrote %d flows for %d-%d.", nrow(panel), min(years), max(years)))
