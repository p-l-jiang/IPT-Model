# Counterfactual scenarios.
#
# A scenario file (config/scenarios/*.yml) lists scenarios, each a list of
# shocks applied cumulatively (multiplicatively in tau_hat):
#
#   - id: us_tariff_35
#     label: "US 35% tariff on all imports"
#     tariff_treatment: iceberg          # optional; default from the config
#     migration_elasticity: 0            # optional; default from the config
#     report: change                     # optional; or gains_from_trade
#     shocks:
#       - {type: tariff, importers: [USA], exporters: all, sectors: all, rate: 0.35}
#
# Shock types
#   iceberg                  tau_hat *= factor
#   tariff                   ad valorem tariff `rate` (added to baseline tariffs);
#                            treatment "iceberg" (legacy) multiplies tau_hat by
#                            (1 + rate) instead and raises no revenue
#   autarky                  prohibitive trade costs (tau_hat = Inf); with
#                            report: gains_from_trade the results are the gains
#                            of the observed equilibrium relative to autarky
#   measured_cost_reduction  lower measured costs (index - 1) by `share`
#                            (Albrecht and Tombe, 2016, Table 6, share = 0.10)
#   eliminate_nongeographic  remove the non-geographic part of measured costs
#   eliminate_asymmetries    lower each cost to that of the cheaper direction
#   eliminate_measured       remove all measured costs
# The measured-cost shocks use the decomposition written by
# scripts/05_estimate_trade_costs.R and apply to importer-exporter pairs among
# `importers` and `exporters` (default: domestic, i.e. interprovincial pairs);
# the elimination shocks accept `fraction` (default 1), the share of the log
# cost removed, so that two shocks with fraction 0.5 remove the geometric
# average of two cost measures.
# Region groups: all, domestic (alias canada), provinces, territories, foreign,
# or a list of region codes. `exporters: all` excludes each importer itself.
# Sector groups: all, goods, services, or a list of sector codes.

measured_shock_types <- c("measured_cost_reduction", "eliminate_nongeographic",
                          "eliminate_asymmetries", "eliminate_measured")

#' Read every scenario listed in the configuration.
load_scenarios <- function(cfg, files = cfg$scenarios) {
  out <- list()
  for (f in files) {
    spec <- yaml::read_yaml(f)
    for (s in spec$scenarios) {
      s$file <- f
      out[[s$id]] <- s
    }
  }
  out
}

resolve_regions <- function(x, cfg) {
  regions <- load_regions()
  dom <- cfg$regions$domestic
  if (length(x) == 1 && x %in% c("all", "domestic", "canada", "provinces", "territories", "foreign")) {
    return(switch(x,
      all = model_regions(cfg),
      domestic = dom,
      canada = dom,
      provinces = intersect(dom, regions$region_id[regions$type == "province"]),
      territories = intersect(dom, regions$region_id[regions$type == "territory"]),
      foreign = cfg$regions$foreign))
  }
  bad <- setdiff(x, model_regions(cfg))
  if (length(bad) > 0) {
    stopf("Unknown region(s) in scenario: %s (quote region codes in YAML; an unquoted ON is read as TRUE).",
          paste(bad, collapse = ", "))
  }
  x
}

resolve_sectors <- function(x, cfg) {
  goods <- goods_sectors(cfg)
  if (length(x) == 1 && x %in% c("all", "goods", "services")) {
    return(switch(x, all = names(goods), goods = names(goods)[goods], services = names(goods)[!goods]))
  }
  bad <- setdiff(x, names(goods))
  if (length(bad) > 0) stopf("Unknown sector(s) in scenario: %s", paste(bad, collapse = ", "))
  x
}

#' tau_hat implied by a measured-cost shock for the rows of the decomposition.
measured_shock_values <- function(sh, cc, scenario_id) {
  if (sh$type == "measured_cost_reduction") {
    share <- sh$share %||% 0.10
    idx <- if ("tau_index" %in% names(cc)) cc$tau_index else cc$tau_bar
    return(if_else(idx > 1, (1 + (1 - share) * (idx - 1)) / idx, 1))
  }
  col <- switch(sh$type,
    eliminate_nongeographic = "tau_hat_nongeo",
    eliminate_asymmetries = "tau_hat_asym",
    eliminate_measured = "tau_hat_all")
  if (!col %in% names(cc)) {
    stopf("Scenario %s needs column %s in the trade-cost decomposition; re-run scripts/05_estimate_trade_costs.R.",
          scenario_id, col)
  }
  coalesce(cc[[col]], 1)^(sh$fraction %||% 1)
}

#' Translate a scenario into iceberg-cost changes and counterfactual tariffs.
#'
#' @param costs Output of decompose_trade_costs() (needed for the measured-cost shocks).
#' @return List: tau_hat, tariff_new, tariff_treatment, migration_elasticity, report.
build_shocks <- function(scenario, base, cfg, costs = NULL) {
  dn <- dimnames(base$pi)
  tau_hat <- array(1, dim(base$pi), dn)
  tariff_new <- base$tariff
  treatment <- scenario$tariff_treatment %||% cfg$scenario_defaults$tariff_treatment %||% "iceberg"
  if (!treatment %in% c("iceberg", "ad_valorem")) stopf("Unknown tariff_treatment: %s", treatment)
  report <- scenario$report %||% "change"
  if (!report %in% c("change", "gains_from_trade")) stopf("Unknown report type: %s", report)

  for (sh in scenario$shocks) {
    sectors <- resolve_sectors(sh$sectors %||% "all", cfg)
    if (sh$type %in% c("iceberg", "tariff", "autarky")) {
      importers <- resolve_regions(sh$importers %||% "all", cfg)
      exporters <- resolve_regions(sh$exporters %||% "all", cfg)
      for (n in importers) {
        ex <- setdiff(exporters, n)
        if (length(ex) == 0) next
        if (sh$type == "iceberg") {
          tau_hat[n, ex, sectors] <- tau_hat[n, ex, sectors] * sh$factor
        } else if (sh$type == "autarky") {
          tau_hat[n, ex, sectors] <- Inf
        } else if (treatment == "iceberg") {
          tau_hat[n, ex, sectors] <- tau_hat[n, ex, sectors] * (1 + sh$rate)
        } else {
          tariff_new[n, ex, sectors] <- tariff_new[n, ex, sectors] + sh$rate
        }
      }
    } else if (sh$type %in% measured_shock_types) {
      if (is.null(costs)) stopf("Scenario %s needs measured trade costs.", scenario$id)
      importers <- resolve_regions(sh$importers %||% "domestic", cfg)
      exporters <- resolve_regions(sh$exporters %||% "domestic", cfg)
      cc <- costs |> filter(sector %in% sectors, dest %in% importers, origin %in% exporters, origin != dest)
      idx <- cbind(match(cc$dest, dn[[1]]), match(cc$origin, dn[[2]]), match(cc$sector, dn[[3]]))
      ok <- stats::complete.cases(idx)
      tau_hat[idx[ok, , drop = FALSE]] <- tau_hat[idx[ok, , drop = FALSE]] *
        measured_shock_values(sh, cc, scenario$id)[ok]
    } else {
      stopf("Unknown shock type '%s' in scenario %s.", sh$type, scenario$id)
    }
  }
  list(tau_hat = tau_hat, tariff_new = tariff_new, tariff_treatment = treatment,
       migration_elasticity = scenario$migration_elasticity %||% cfg$migration$elasticity %||% 0,
       report = report)
}

#' Check that prohibitive trade costs leave every group of regions that can
#' still trade with each other able to finance its trade imbalances.
check_autarky_feasible <- function(tau_hat, base, scenario_id) {
  if (all(is.finite(tau_hat))) return(invisible(TRUE))
  N <- length(base$regions)
  link <- apply(is.finite(tau_hat) & base$pi > 0, c(1, 2), any)
  link <- link | t(link)
  comp <- rep(NA_integer_, N)
  for (s in seq_len(N)) {
    if (!is.na(comp[s])) next
    queue <- s
    comp[s] <- s
    while (length(queue) > 0) {
      k <- queue[1]
      queue <- queue[-1]
      nb <- which(link[k, ] & is.na(comp))
      comp[nb] <- s
      queue <- c(queue, nb)
    }
  }
  imbalance <- tapply(base$D, comp, sum)
  if (any(abs(imbalance) > 1e-6 * sum(base$VA))) {
    stopf(paste0("Scenario %s isolates groups of regions whose trade imbalances do not sum to zero; ",
                 "gains-from-trade experiments need balanced trade (calibration$deficits: balanced or purge)."),
          scenario_id)
  }
  invisible(TRUE)
}

#' Solve one scenario.
run_scenario <- function(scenario, base, cfg, costs = NULL) {
  shocks <- build_shocks(scenario, base, cfg, costs)
  check_autarky_feasible(shocks$tau_hat, base, scenario$id)
  log_info(sprintf("Scenario %s (migration elasticity %g, tariffs: %s) ...", scenario$id,
                   shocks$migration_elasticity, shocks$tariff_treatment))
  sol <- solve_counterfactual(base, tau_hat = shocks$tau_hat, tariff_new = shocks$tariff_new,
                              migration_elasticity = shocks$migration_elasticity,
                              mobile = base$domestic, control = cfg$solver)
  sol$scenario <- scenario
  sol$shocks <- shocks
  sol
}
