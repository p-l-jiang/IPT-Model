# Measure trade costs (Head-Ries index), estimate exporter-specific
# (asymmetric) costs and decompose measured costs into geographic and
# non-geographic components.
#
# Usage: Rscript scripts/05_estimate_trade_costs.R [--config config/default.yml]

source("src/load.R")
cfg <- script_config()
theta <- load_trade_elasticities(cfg)
panel <- readr::read_csv(processed_path(cfg, "trade_flows.csv.gz"), show_col_types = FALSE)
distances <- load_distances(cfg)

hr <- trade_cost_panel(cfg, panel, theta)
gravity <- estimate_gravity(cfg, hr, distances)
asym <- NULL
if (!isFALSE(cfg$trade_costs$asymmetries)) asym <- estimate_asymmetries(cfg, panel, theta, distances)
costs <- decompose_trade_costs(cfg, gravity, target_year_costs(cfg, panel, theta), distances, asym)

flows <- panel |> filter(year == cfg$years$target)
summary <- bind_rows(
  summarise_trade_costs(costs, flows) |> mutate(group = "all", key = "all"),
  summarise_trade_costs(costs, flows, "sector") |> mutate(group = "sector") |> rename(key = sector),
  summarise_trade_costs(costs, flows, "origin") |> mutate(group = "exporter") |> rename(key = origin),
  summarise_trade_costs(costs, flows, "dest") |> mutate(group = "importer") |> rename(key = dest)
) |> relocate(group, key)

readr::write_csv(hr, processed_path(cfg, "measured_trade_costs.csv.gz"))
write_table(gravity$coefficients, processed_path(cfg, "gravity_coefficients.csv"))
if (!is.null(asym)) write_table(asym, processed_path(cfg, "exporter_costs.csv"))
write_table(costs, processed_path(cfg, "trade_cost_decomposition.csv"))
write_table(summary, processed_path(cfg, "trade_cost_summary.csv"))
log_info(sprintf("Estimated gravity regressions for %d sectors; average interprovincial cost %.1f%%.",
                 length(unique(gravity$coefficients$sector)), summary$measured_cost[1]))
