scenario_cfg <- function() {
  list(regions = list(domestic = c("ON", "QC"), foreign = c("USA", "ROW")),
       sectors = list(scheme = "base37"),
       scenario_defaults = list(tariff_treatment = "iceberg"),
       migration = list(elasticity = 0))
}

scenario_base <- function() {
  regions <- c("ON", "QC", "USA", "ROW")
  sectors <- load_base_sectors()$sector_id
  dn <- list(dest = regions, origin = regions, sector = sectors)
  list(regions = regions, sectors = sectors, domestic = c("ON", "QC"),
       pi = array(0.25, c(4, 4, length(sectors)), dn),
       tariff = array(0, c(4, 4, length(sectors)), dn))
}

test_that("iceberg shocks apply to the listed pairs only, never to own trade", {
  cfg <- scenario_cfg()
  base <- scenario_base()
  sc <- list(id = "x", shocks = list(list(type = "iceberg", importers = "domestic",
                                          exporters = "domestic", sectors = "all", factor = 0.9)))
  sh <- build_shocks(sc, base, cfg)
  expect_equal(unique(as.vector(sh$tau_hat["ON", "QC", ])), 0.9)
  expect_equal(unique(as.vector(sh$tau_hat["QC", "ON", ])), 0.9)
  expect_equal(unique(as.vector(sh$tau_hat["ON", "ON", ])), 1)
  expect_equal(unique(as.vector(sh$tau_hat["USA", "ON", ])), 1)
})

test_that("tariffs are iceberg costs or ad valorem taxes depending on the treatment", {
  cfg <- scenario_cfg()
  base <- scenario_base()
  shock <- list(type = "tariff", importers = "USA", exporters = "all", sectors = "goods", rate = 0.35)
  ice <- build_shocks(list(id = "a", shocks = list(shock)), base, cfg)
  expect_equal(unique(as.vector(ice$tau_hat["USA", c("ON", "QC", "ROW"), "MTV"])), 1.35)
  expect_equal(unique(as.vector(ice$tau_hat["USA", "USA", ])), 1)
  expect_equal(unique(as.vector(ice$tau_hat["USA", "ON", "FIN"])), 1)  # services untouched
  expect_equal(sum(ice$tariff_new), 0)

  adv <- build_shocks(list(id = "b", tariff_treatment = "ad_valorem", shocks = list(shock)), base, cfg)
  expect_equal(unique(as.vector(adv$tariff_new["USA", c("ON", "QC", "ROW"), "MTV"])), 0.35)
  expect_equal(unique(as.vector(adv$tau_hat)), 1)
})

test_that("measured-cost scenarios use the trade-cost decomposition", {
  cfg <- scenario_cfg()
  base <- scenario_base()
  costs <- tibble(origin = c("ON", "QC"), dest = c("QC", "ON"), sector = "MTV",
                  tau_bar = c(2, 2), tau_hat_nongeo = c(0.8, 0.8), tau_hat_all = c(0.5, 0.5))
  sc <- list(id = "m", shocks = list(list(type = "measured_cost_reduction", sectors = "goods", share = 0.1)))
  sh <- build_shocks(sc, base, cfg, costs)
  expect_equal(unname(sh$tau_hat["QC", "ON", "MTV"]), (1 + 0.9 * 1) / 2)
  sc2 <- list(id = "n", shocks = list(list(type = "eliminate_nongeographic", sectors = "goods")))
  expect_equal(unname(build_shocks(sc2, base, cfg, costs)$tau_hat["ON", "QC", "MTV"]), 0.8)
  sc3 <- list(id = "e", shocks = list(list(type = "eliminate_measured", sectors = c("MTV"))))
  expect_equal(unname(build_shocks(sc3, base, cfg, costs)$tau_hat["ON", "QC", "MTV"]), 0.5)
})

test_that("unknown regions produce a helpful error", {
  cfg <- scenario_cfg()
  sc <- list(id = "z", shocks = list(list(type = "iceberg", importers = c("TRUE"),
                                          exporters = "all", factor = 0.9)))
  expect_error(build_shocks(sc, scenario_base(), cfg), "quote region codes")
})

test_that("measured-cost shocks can target pairs, asymmetries and fractions", {
  cfg <- scenario_cfg()
  base <- scenario_base()
  costs <- tibble(origin = c("ON", "QC", "USA", "ON"), dest = c("QC", "ON", "ON", "USA"), sector = "MTV",
                  tau_bar = 2, tau_index = 2, tau_hat_nongeo = 0.8, tau_hat_asym = c(0.9, 1, 1, 1),
                  tau_hat_all = 0.5)
  # Default pairs are interprovincial.
  sh <- build_shocks(list(id = "a", shocks = list(list(type = "eliminate_measured", sectors = "MTV"))),
                     base, cfg, costs)
  expect_equal(unname(sh$tau_hat["USA", "ON", "MTV"]), 1)
  expect_equal(unname(sh$tau_hat["ON", "QC", "MTV"]), 0.5)
  # External pairs only, one direction.
  sh <- build_shocks(list(id = "b", shocks = list(list(type = "eliminate_measured", sectors = "MTV",
                                                       importers = "foreign", exporters = "domestic"))),
                     base, cfg, costs)
  expect_equal(unname(sh$tau_hat["USA", "ON", "MTV"]), 0.5)
  expect_equal(unname(sh$tau_hat["ON", "USA", "MTV"]), 1)
  # Asymmetries apply to the costlier direction only.
  sh <- build_shocks(list(id = "c", shocks = list(list(type = "eliminate_asymmetries", sectors = "MTV"))),
                     base, cfg, costs)
  expect_equal(unname(sh$tau_hat[c("QC", "ON"), c("ON", "QC"), "MTV"][cbind(1:2, 1:2)]), c(0.9, 1))
  # Two half eliminations remove the geometric average of the two measures.
  sh <- build_shocks(list(id = "d", shocks = list(
    list(type = "eliminate_nongeographic", sectors = "MTV", fraction = 0.5),
    list(type = "eliminate_asymmetries", sectors = "MTV", fraction = 0.5))), base, cfg, costs)
  expect_equal(unname(sh$tau_hat["QC", "ON", "MTV"]), sqrt(0.8 * 0.9))
})

test_that("autarky shocks are prohibitive and need balanced trade when regions are isolated", {
  cfg <- scenario_cfg()
  base <- scenario_base()
  sh <- build_shocks(list(id = "x", report = "gains_from_trade",
                          shocks = list(list(type = "autarky", importers = "domestic", exporters = "domestic"))),
                     base, cfg)
  expect_true(all(is.infinite(sh$tau_hat["ON", "QC", ])))
  expect_true(all(is.finite(sh$tau_hat["ON", "USA", ])))
  expect_equal(sh$report, "gains_from_trade")
  # Isolating Canada from the world with an external imbalance is infeasible.
  full <- build_shocks(list(id = "y", shocks = list(
    list(type = "autarky", importers = "domestic", exporters = "foreign"),
    list(type = "autarky", importers = "foreign", exporters = "domestic"))), base, cfg)
  base$D <- c(ON = 1, QC = 1, USA = -1, ROW = -1)
  base$VA <- c(ON = 10, QC = 10, USA = 10, ROW = 10)
  expect_error(check_autarky_feasible(full$tau_hat, base, "y"), "balanced trade")
  base$D <- c(ON = 1, QC = -1, USA = 1, ROW = -1)
  expect_true(check_autarky_feasible(full$tau_hat, base, "y"))
})
