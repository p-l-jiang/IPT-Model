# Export solved cases for the independent Python cross-check.
#
# Usage (from the repository root):
#   Rscript tests/crosscheck/export_cases.R [--real]
#   python3 tests/crosscheck/solver_crosscheck.py
#
# Writes JSON files to tests/crosscheck/cases/ (git-ignored). With --real, also
# exports the calibrated baseline of config/default.yml and a US-tariff
# scenario solved with ad valorem tariffs and migration.

source("src/load.R")
source("tests/testthat/helper-synthetic.R")
out_dir <- ensure_dir("tests/crosscheck/cases")

export_case <- function(name, base, tau_hat, tariff_new, kappa, sol) {
  payload <- list(
    regions = base$regions, sectors = base$sectors,
    mobile = if (kappa > 0) base$domestic else character(0), kappa = kappa,
    pi = base$pi, phi = base$phi, gamma = base$gamma, beta = base$beta,
    theta = unname(base$theta), tariff = base$tariff, D = unname(base$D),
    VA = unname(base$VA), I = unname(base$I), population = unname(base$population),
    tau_hat = tau_hat, tariff_new = tariff_new,
    solution = list(w_hat = unname(sol$w_hat), L_hat = unname(sol$L_hat),
                    P_hat = unname(sol$P_hat), real_income = unname((sol$I / base$I) / sol$P_hat))
  )
  # Arrays are exported in column-major order with their dimensions.
  payload <- lapply(payload, function(x) if (is.array(x)) list(dim = dim(x), data = as.vector(x)) else x)
  jsonlite::write_json(payload, file.path(out_dir, paste0(name, ".json")), digits = NA, auto_unbox = TRUE, na = "null")
  log_info("Exported ", name)
}

base <- make_synthetic_base(N = 5, J = 4, seed = 21)
tau <- random_tau_hat(base, 0.7, 1.3, seed = 22)
tar <- base$tariff
tar["R1", -1, ] <- 0.2
sol <- solve_counterfactual(base, tau_hat = tau, tariff_new = tar, migration_elasticity = 1.5,
                            mobile = base$domestic)
export_case("synthetic", base, tau, tar, 1.5, sol)

if ("--real" %in% commandArgs(trailingOnly = TRUE)) {
  cfg <- load_config()
  base <- readRDS(processed_path(cfg, "baseline.rds"))
  sc <- load_scenarios(cfg)[["us_tariff_35_canada_retaliates"]]
  sc$tariff_treatment <- "ad_valorem"
  sh <- build_shocks(sc, base, cfg)
  sol <- solve_counterfactual(base, tau_hat = sh$tau_hat, tariff_new = sh$tariff_new,
                              migration_elasticity = 1.5, mobile = base$domestic,
                              control = cfg$solver)
  export_case("real_us_tariff_ad_valorem_migration", base, sh$tau_hat, sh$tariff_new, 1.5, sol)
}
