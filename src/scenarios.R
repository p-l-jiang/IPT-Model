# Counterfactual scenarios.
#
# A scenario file (config/scenarios/*.yml) lists scenarios, each a list of
# shocks applied cumulatively:
#
#   - id: us_tariff_35
#     label: "US 35% tariff on all imports"
#     tariff_treatment: iceberg          # optional; default from the config
#     migration_elasticity: 0            # optional; default from the config
#     shocks:
#       - {type: tariff, importers: [USA], exporters: all, sectors: all, rate: 0.35}
#
# Shock types
#   iceberg                  tau_hat *= factor
#   tariff                   ad valorem tariff `rate` (added to baseline tariffs);
#                            treatment "iceberg" (legacy) multiplies tau_hat by
#                            (1 + rate) instead and raises no revenue
#   measured_cost_reduction  lower measured interprovincial costs (tau_bar - 1)
#                            by `share` (Table 6, column 1 uses share = 0.10)
#   eliminate_nongeographic  remove the non-geographic part of measured
#                            interprovincial costs (Table 6, column 4)
#   eliminate_measured       remove all measured interprovincial costs (Table 6,
#                            column 5)
# Region groups: all, domestic (alias canada), provinces, territories, foreign,
# or a list of region codes. `exporters: all` excludes each importer itself.
# Sector groups: all, goods, services, or a list of sector codes.

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

#' Translate a scenario into iceberg-cost changes and counterfactual tariffs.
#'
#' @param costs Output of decompose_trade_costs() (needed for the measured-cost shocks).
#' @return List: tau_hat, tariff_new, tariff_treatment, migration_elasticity.
build_shocks <- function(scenario, base, cfg, costs = NULL) {
  dn <- dimnames(base$pi)
  tau_hat <- array(1, dim(base$pi), dn)
  tariff_new <- base$tariff
  treatment <- scenario$tariff_treatment %||% cfg$scenario_defaults$tariff_treatment %||% "iceberg"
  if (!treatment %in% c("iceberg", "ad_valorem")) stopf("Unknown tariff_treatment: %s", treatment)

  for (sh in scenario$shocks) {
    sectors <- resolve_sectors(sh$sectors %||% "all", cfg)
    if (sh$type %in% c("iceberg", "tariff")) {
      importers <- resolve_regions(sh$importers, cfg)
      exporters <- resolve_regions(sh$exporters, cfg)
      for (n in importers) {
        ex <- setdiff(exporters, n)
        if (length(ex) == 0) next
        if (sh$type == "iceberg") {
          tau_hat[n, ex, sectors] <- tau_hat[n, ex, sectors] * sh$factor
        } else if (treatment == "iceberg") {
          tau_hat[n, ex, sectors] <- tau_hat[n, ex, sectors] * (1 + sh$rate)
        } else {
          tariff_new[n, ex, sectors] <- tariff_new[n, ex, sectors] + sh$rate
        }
      }
    } else if (sh$type %in% c("measured_cost_reduction", "eliminate_nongeographic", "eliminate_measured")) {
      if (is.null(costs)) stopf("Scenario %s needs measured trade costs.", scenario$id)
      col <- switch(sh$type,
        measured_cost_reduction = "tau_hat_measured",
        eliminate_nongeographic = "tau_hat_nongeo",
        eliminate_measured = "tau_hat_all")
      cc <- costs |> filter(sector %in% sectors)
      if (sh$type == "measured_cost_reduction") {
        share <- sh$share %||% 0.10
        cc <- cc |> mutate(tau_hat_measured = if_else(tau_bar > 1, (1 + (1 - share) * (tau_bar - 1)) / tau_bar, 1))
      }
      idx <- cbind(match(cc$dest, dn[[1]]), match(cc$origin, dn[[2]]), match(cc$sector, dn[[3]]))
      tau_hat[idx] <- tau_hat[idx] * cc[[col]]
    } else {
      stopf("Unknown shock type '%s' in scenario %s.", sh$type, scenario$id)
    }
  }
  list(tau_hat = tau_hat, tariff_new = tariff_new, tariff_treatment = treatment,
       migration_elasticity = scenario$migration_elasticity %||% cfg$migration$elasticity %||% 0)
}

#' Solve one scenario.
run_scenario <- function(scenario, base, cfg, costs = NULL) {
  shocks <- build_shocks(scenario, base, cfg, costs)
  log_info(sprintf("Scenario %s (migration elasticity %g, tariffs: %s) ...", scenario$id,
                   shocks$migration_elasticity, shocks$tariff_treatment))
  sol <- solve_counterfactual(base, tau_hat = shocks$tau_hat, tariff_new = shocks$tariff_new,
                              migration_elasticity = shocks$migration_elasticity,
                              mobile = base$domestic, control = cfg$solver)
  sol$scenario <- scenario
  sol$shocks <- shocks
  sol
}
