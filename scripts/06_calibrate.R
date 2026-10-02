# Calibrate the baseline equilibrium for the target year.
#
# Usage: Rscript scripts/06_calibrate.R [--config config/default.yml]

source("src/load.R")
cfg <- script_config()
year <- cfg$years$target
theta <- load_trade_elasticities(cfg)
io <- readRDS(processed_path(cfg, "io_parameters.rds"))
flows <- readr::read_csv(processed_path(cfg, "trade_flows.csv.gz"), show_col_types = FALSE) |>
  filter(year == !!year)
population <- baseline_population(cfg, year)
base <- build_baseline(cfg, flows, io, theta, population, data_value_added(io, cfg))

# Check that the baseline is an equilibrium: a shock-free counterfactual must
# return no change.
check <- solve_counterfactual(base, control = cfg$solver)
dev <- max(abs(c(check$w_hat - 1, check$p_hat - 1)))
if (dev > 1e-8) stopf("Baseline is not an equilibrium (max deviation %.2e).", dev)

saveRDS(base, processed_path(cfg, "baseline.rds"))
write_table(base$diagnostics, processed_path(cfg, "baseline_diagnostics.csv"))
if (!is.null(attr(theta, "table"))) {
  write_table(attr(theta, "table"), processed_path(cfg, "trade_elasticities.csv"))
} else {
  write_table(tibble(sector_id = names(theta), theta = unname(theta)),
              processed_path(cfg, "trade_elasticities.csv"))
}
log_info(sprintf("Baseline calibrated (identity check: max deviation %.1e).", dev))
print(base$diagnostics |> select(region, va_data, va_model, va_gap_pct, deficit_pct_va) |>
        mutate(across(where(is.numeric), \(x) round(x, 2))), n = Inf)
