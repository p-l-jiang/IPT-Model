# Replicate the published experiments and explain the differences.
#
# 1. Runs the configurations that reproduce the setups of Albrecht and Tombe
#    (2016), Alvarez, Krznar and Tombe (2019) and Manucha and Tombe (2022), plus
#    variants (e.g. the uniform trade elasticities of Alvarez et al., appendix II).
# 2. Runs "bridges": sequences of variants that move one setting at a time from
#    a paper's setup towards config/default.yml, to attribute the difference
#    between the paper and the main model to individual modelling choices.
# 3. Compares results with config/benchmarks/published_results.csv.
#
# Usage: Rscript scripts/replication/run_replications.R [--group at|akt|mli] [--skip-runs]
# Outputs: output/replication/{comparison.csv, bridges.csv, comparison.md}.
# Each run takes 1-3 minutes; the full set about 30 minutes (run the three
# groups in parallel to save time).

source("src/load.R")
args <- commandArgs(trailingOnly = TRUE)
group_filter <- if ("--group" %in% args) args[match("--group", args) + 1] else NULL
skip_runs <- "--skip-runs" %in% args

# ---------------------------------------------------------------------------
# Runs. `from` is the first pipeline step to execute; earlier products are
# copied from `parent`. `sets` are configuration overrides (see src/config.R).
# ---------------------------------------------------------------------------
at_cfg <- "config/replication_albrecht_tombe_2016.yml"
akt_cfg <- "config/replication_alvarez_krznar_tombe_2019.yml"
mli_cfg <- "config/replication_manucha_tombe_2022.yml"
dom13 <- '["NL", "PE", "NS", "NB", "QC", "ON", "MB", "SK", "AB", "BC", "YT", "NT", "NU"]'
akt_gravity_at <- c("trade_costs.sample=interprovincial", "trade_costs.regressors=[log_dist, adjacent]",
                    "trade_costs.year_interactions=[]", "trade_costs.geographic=[log_dist, adjacent]",
                    "years.panel=[2010, 2016]")

run <- function(name, group, config, from, sets = character(0), parent = NULL, step = NA_character_) {
  list(name = name, group = group, config = config, from = from, sets = sets, parent = parent, step = step)
}
chain <- function(group, config, steps, scenarios = NULL) {
  # Cumulative bridge: each step adds its overrides to the previous ones.
  out <- list()
  acc <- if (is.null(scenarios)) character(0) else paste0("scenarios=", scenarios)
  prev <- NULL
  for (s in steps) {
    acc <- c(acc, s$sets)
    out[[length(out) + 1]] <- run(s$name, group, config, s$from, acc, prev, s$step)
    prev <- s$name
  }
  out
}
st <- function(name, from, step, sets) list(name = name, from = from, step = step, sets = sets)

runs <- c(
  list(
    run("albrecht_tombe_2016", "at", at_cfg, 3, step = "Paper setup (2016 data)"),
    run("alvarez_krznar_tombe_2019", "akt", akt_cfg, 3, step = "Paper setup (2016 data)"),
    run("manucha_tombe_2022", "mli", mli_cfg, 3, step = "Paper setup (2018 data)")
  ),
  list(
    run("at_year2018", "at", at_cfg, 3, c("name=at_year2018", "years.target=2018", "years.panel=[2018, 2018]"),
        step = "Paper setup, 2018 data"),
    run("at_year2022", "at", at_cfg, 3, c("name=at_year2022", "years.target=2022", "years.panel=[2022, 2022]"),
        step = "Paper setup, 2022 data"),
    run("akt_own_pairs", "akt", akt_cfg, 5, c("name=akt_own_pairs", "trade_costs.own_pairs=true"),
        "alvarez_krznar_tombe_2019", "Within-province pairs in the gravity regressions"),
    run("mli_sectors37", "mli", mli_cfg, 3,
        c("name=mli_sectors37", "sectors.scheme=base37",
          "trade_elasticities.file=config/parameters/theta_manucha_tombe_2022_base37.csv",
          "trade_costs.exclude_sectors=[UTL, CON, PAD]"),
        step = "Paper setup with the 37 base sectors (same elasticities)")
  ),
  lapply(c(4, 6.5, 8), function(th) {
    run(paste0("akt_theta", sub(".", "_", th, fixed = TRUE)), "akt", akt_cfg, 5,
        c(paste0("name=akt_theta", sub(".", "_", th, fixed = TRUE)), "trade_elasticities.method=uniform",
          paste0("trade_elasticities.goods_theta=", th), "trade_elasticities.services_theta=5"),
        "alvarez_krznar_tombe_2019", paste("Uniform goods elasticity", th))
  }),
  chain("at", at_cfg, scenarios = "[config/scenarios/albrecht_tombe_2016.yml]", list(
    st("at_b1_deficits", 6, "+ observed trade imbalances", "calibration.deficits=data"),
    st("at_b2_regional_io", 4, "+ province-specific input-output structure", "io_parameters.source=regional"),
    st("at_b3_regions", 3, "+ territories and the United States", c(paste0("regions.domestic=", dom13), 'regions.foreign=["USA", "ROW"]')),
    st("at_b4_sectors", 3, "+ 37 sectors (paper elasticities)", c("sectors.scheme=base37", "trade_elasticities.file=config/parameters/theta_albrecht_tombe_2016_base37.csv")),
    st("at_b5_theta", 5, "+ Bank of Canada-rule elasticities", "trade_elasticities.method=boc2018_rule"),
    st("at_b6_gravity", 3, "+ adjacency, 2010-2016 panel, symmetric index", c("trade_costs.regressors=[log_dist, adjacent]", "years.panel=[2010, 2016]", "trade_costs.measured_index=symmetric")),
    st("at_b7_year", 3, "+ 2022 data (main model)", c("years.target=2022", "years.panel=[2010, 2022]"))
  )),
  chain("akt", akt_cfg, scenarios = "[config/scenarios/alvarez_krznar_tombe_2019.yml]", list(
    st("akt_b1_gravity", 3, "Albrecht-Tombe gravity (log normalized distance)", akt_gravity_at),
    st("akt_b2_migration", 6, "+ no labour mobility", "migration.elasticity=0"),
    st("akt_b3_deficits", 6, "+ observed trade imbalances", "calibration.deficits=data"),
    st("akt_b4_regional_io", 4, "+ province-specific input-output structure", "io_parameters.source=regional"),
    st("akt_b5_sectors", 3, "+ 37 sectors (paper elasticities)", c("sectors.scheme=base37", "trade_elasticities.file=config/parameters/theta_albrecht_tombe_2016_base37.csv", "trade_costs.exclude_sectors=[UTL, CON, PAD]")),
    st("akt_b6_theta", 5, "+ Bank of Canada-rule elasticities", "trade_elasticities.method=boc2018_rule"),
    st("akt_b7_year", 3, "+ 2022 data (main model)", c("years.target=2022", "years.panel=[2010, 2022]"))
  )),
  chain("mli", mli_cfg, scenarios = "[config/scenarios/manucha_tombe_2022.yml]", list(
    st("mli_b1_migration", 6, "No labour mobility", "migration.elasticity=0"),
    st("mli_b2_usa", 3, "+ United States as a separate region", 'regions.foreign=["USA", "ROW"]'),
    st("mli_b3_sectors", 3, "+ 37 sectors, Bank of Canada-rule elasticities", c("sectors.scheme=base37", "trade_elasticities.method=boc2018_rule", "trade_costs.exclude_sectors=[UTL, CON, PAD]")),
    st("mli_b4_gravity", 3, "+ adjacency, 2010-2018 panel", c("trade_costs.regressors=[log_dist, adjacent]", "years.panel=[2010, 2018]")),
    st("mli_b5_year", 3, "+ 2022 data (main model)", c("years.target=2022", "years.panel=[2010, 2022]"))
  ))
)
# Bridge runs need their own names.
runs <- lapply(runs, function(r) {
  if (!any(startsWith(r$sets, "name=")) && !r$name %in% c("albrecht_tombe_2016", "alvarez_krznar_tombe_2019",
                                                         "manucha_tombe_2022")) {
    r$sets <- c(paste0("name=", r$name), r$sets)
  }
  r
})
# The first bridge step's parent is the paper run.
for (k in seq_along(runs)) {
  if (is.null(runs[[k]]$parent) && grepl("_b1_", runs[[k]]$name)) {
    runs[[k]]$parent <- c(at = "albrecht_tombe_2016", akt = "alvarez_krznar_tombe_2019",
                          mli = "manucha_tombe_2022")[[runs[[k]]$group]]
  }
}
if (!is.null(group_filter)) runs <- Filter(function(r) r$group == group_filter, runs)

products <- list(
  `4` = c("trade_flows.csv.gz", "us_trade_shares.csv"),
  `5` = c("io_parameters.rds", "phi.csv", "beta.csv", "gamma.csv.gz"),
  `6` = c("measured_trade_costs.csv.gz", "gravity_coefficients.csv", "trade_cost_decomposition.csv",
          "exporter_costs.csv", "trade_cost_summary.csv"),
  `7` = c("baseline.rds", "baseline_diagnostics.csv", "trade_elasticities.csv")
)
execute <- function(r) {
  dest <- ensure_dir(file.path("data/processed", r$name))
  if (!is.null(r$parent)) {
    for (k in names(products)) {
      if (r$from >= as.integer(k)) {
        src <- file.path("data/processed", r$parent, products[[k]])
        file.copy(src[file.exists(src)], dest, overwrite = TRUE)
      }
    }
  }
  sets <- as.vector(rbind("--set", r$sets))
  log_info(sprintf("Run %s (from step %d) ...", r$name, r$from))
  status <- system2("Rscript", c("scripts/run_all.R", "--config", r$config, "--from", r$from, shQuote(sets)),
                    stdout = file.path(dest, "run.log"), stderr = file.path(dest, "run.log"))
  if (status != 0) warnf("Run %s failed; see %s.", r$name, file.path(dest, "run.log"))
}
if (!skip_runs) for (r in runs) execute(r)

# ---------------------------------------------------------------------------
# Comparison with the published results.
# ---------------------------------------------------------------------------
read_out <- function(run_name, scenario, file) {
  path <- file.path("output", run_name, scenario, file)
  if (!file.exists(path)) return(NULL)
  readr::read_csv(path, show_col_types = FALSE)
}
model_value <- function(run_name, scenario, region, measure) {
  if (region == "CAN") {
    can <- read_out(run_name, scenario, "canada.csv")
    if (is.null(can)) return(NA_real_)
    return(can$change_pct[can$measure == "real_income"])
  }
  reg <- read_out(run_name, scenario, "regions.csv")
  if (is.null(reg)) return(NA_real_)
  col <- switch(measure, welfare = "real_income", real_gdp = "real_income",
                real_gdp_per_capita = "real_income_per_capita", employment = "population")
  members <- switch(region, NT_NU = c("NT", "NU"), NWPTA = c("BC", "AB", "SK", "MB"), region)
  rows <- reg |> filter(region %in% members)
  if (nrow(rows) == 0) return(NA_real_)
  if (nrow(rows) == 1) return(rows[[col]])
  # Aggregates of several regions: weights from the run's baseline incomes.
  base <- readRDS(file.path("data/processed", run_name, "baseline.rds"))
  w <- base$I[rows$region]
  sum(w * rows[[col]]) / sum(w)
}
benchmark_target <- function(paper, experiment) {
  run_name <- c(albrecht_tombe_2016 = "albrecht_tombe_2016",
                alvarez_krznar_tombe_2019 = "alvarez_krznar_tombe_2019",
                manucha_tombe_2022 = "manucha_tombe_2022")[[paper]]
  scenario <- experiment
  th <- regmatches(experiment, regexpr("_theta[0-9.]+$", experiment))
  if (length(th) == 1) {
    run_name <- paste0("akt_", sub(".", "_", sub("^_", "", th), fixed = TRUE))
    scenario <- sub("_theta[0-9.]+$", "", experiment)
  }
  if (paper == "manucha_tombe_2022" && experiment == "nwpta_block_max") scenario <- "nwpta_block_nondistance"
  c(run = run_name, scenario = scenario)
}
bench <- readr::read_csv("config/benchmarks/published_results.csv", show_col_types = FALSE) |>
  filter(measure %in% c("welfare", "real_gdp", "real_gdp_per_capita", "employment"))
targets <- t(mapply(benchmark_target, bench$paper, bench$experiment))
bench$run <- targets[, "run"]
bench$scenario <- targets[, "scenario"]
bench$model <- mapply(model_value, bench$run, bench$scenario, bench$region, bench$measure)
comparison <- bench |>
  transmute(paper, source, experiment, region, measure, published = value, model = round(model, 2),
            difference = round(model - value, 2), run, scenario)
out_dir <- ensure_dir("output/replication")
write_table(comparison, file.path(out_dir, "comparison.csv"))

# Bridges: Canada-wide results of every run for the paper's experiments.
bridge_rows <- list()
all_runs <- runs
for (r in all_runs) {
  summ <- file.path("output", r$name, "summary.csv")
  if (!file.exists(summ)) next
  s <- readr::read_csv(summ, show_col_types = FALSE)
  bridge_rows[[r$name]] <- s |> transmute(group = r$group, run = r$name, step = r$step, scenario,
                                          canada_real_income = round(canada_real_income, 2))
}
bridges <- bind_rows(bridge_rows)
write_table(bridges, file.path(out_dir, "bridges.csv"))

# Markdown summary.
md <- c("# Replication of published results", "",
        "Generated by `scripts/replication/run_replications.R`. See `docs/replication.md` for the discussion.", "")
for (p in unique(comparison$paper)) {
  x <- comparison |> filter(paper == p, region == "CAN", measure != "employment") |>
    select(experiment, published, model, difference)
  md <- c(md, paste("##", p), "", markdown_table(x), "")
}
if (nrow(bridges) > 0) {
  for (g in unique(bridges$group)) {
    b <- bridges |> filter(group == g) |>
      tidyr::pivot_wider(id_cols = c(run, step), names_from = scenario, values_from = canada_real_income)
    md <- c(md, paste("## Bridge:", g), "", markdown_table(b), "")
  }
}
writeLines(md, file.path(out_dir, "comparison.md"))
log_info("Wrote ", out_dir, "/comparison.csv, bridges.csv and comparison.md")
