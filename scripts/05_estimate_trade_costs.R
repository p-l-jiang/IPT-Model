# Measure trade costs (Head-Ries index) and decompose interprovincial costs
# into geographic and non-geographic components.
#
# Usage: Rscript scripts/05_estimate_trade_costs.R [--config config/default.yml]

source("src/load.R")
cfg <- script_config()
theta <- load_trade_elasticities(cfg)
panel <- readr::read_csv(processed_path(cfg, "trade_flows.csv.gz"), show_col_types = FALSE)
hr <- trade_cost_panel(cfg, panel, theta)
gravity <- estimate_gravity(cfg, hr, load_distances(cfg))
costs <- decompose_trade_costs(cfg, gravity)

readr::write_csv(hr, processed_path(cfg, "measured_trade_costs.csv.gz"))
write_table(gravity$coefficients, processed_path(cfg, "gravity_coefficients.csv"))
write_table(costs, processed_path(cfg, "trade_cost_decomposition.csv"))
log_info(sprintf("Estimated gravity regressions for %d sectors.",
                 length(unique(gravity$coefficients$sector))))
