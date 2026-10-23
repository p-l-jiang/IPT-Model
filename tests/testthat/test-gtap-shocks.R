source(file.path(getOption("ipt.root", "."), "src", "gtap_shocks.R"))

write_psh <- function(lines) {
  f <- tempfile(fileext = ".psh")
  writeLines(lines, f)
  f
}

test_that("shock files are parsed: comments, line breaks, uniform, commented-out shocks", {
  f <- write_psh(c(
    "! notes ! with exclamation marks",
    'Shock tms("c_Steel", "Canada", "USA") = 25;   ! US tariff',
    '!Shock tms("c_Autos", "Canada", "USA") = 99;',
    'Shock qxs("c_BevTbco", "Canada", "USA") = uniform -45.5;',
    'shock TMS("c_Autos","USA",',
    '   "Canada") = 1.5e1;',
    "swap qxs = tms;"))
  s <- read_gtap_shocks(f)
  expect_equal(nrow(s), 3)
  expect_equal(s$variable, c("tms", "qxs", "tms"))
  expect_equal(s$value, c(25, -45.5, 15))
  expect_equal(s$importer[3], "Canada")
})

test_that("unsupported shocks stop with a message", {
  expect_error(read_gtap_shocks(write_psh('Shock tms(TRAD_COMM, "Canada", "USA") = 25;')), "whole sets")
  expect_error(read_gtap_shocks(write_psh('Shock tms("a", "Canada", "USA") = file x.shk;')), "Unsupported")
  expect_error(read_gtap_shocks(write_psh('Shock to("a", "Canada") = 1;')), "whole sets|other than three")
  expect_error(read_gtap_shocks(write_psh(c('Shock tms("a", "B", "USA") = 1;', 'Shock tms("a", "B", "USA") = 2;'))),
               "more than once")
})

test_that("cell rates are trade-weighted averages over all components, shocked or not", {
  shocks <- tibble(variable = "tms", commodity = c("c_Steel", "c_Steel", "c_NFM"),
                   exporter = c("EU", "Canada", "Canada"), importer = "USA", value = c(40, 20, 10))
  weights <- tibble(
    sector = "BMT",
    commodity = c("c_Steel", "c_Steel", "c_Steel", "c_NFM", "c_Steel"),
    exporter = c("EU", "China", "Canada", "Canada", "China"),
    importer = c("USA", "USA", "USA", "USA", "EU"),
    value = c(3, 1, 1, 3, 5))
  conv <- convert_gtap_shocks(shocks, weights, theta = c(BMT = 8))
  r <- conv$cells
  expect_equal(r$rate[r$ipt_exporter == "ROW"], (3 * 0.40 + 1 * 0) / 4)         # China unshocked
  expect_equal(r$rate[r$ipt_exporter == "domestic"], (1 * 0.20 + 3 * 0.10) / 4)  # two commodities
  expect_equal(nrow(r), 2)                                                       # China -> EU is not an IPT cell
})

test_that("quantity shocks become iceberg costs with the same partial-equilibrium flow change", {
  shocks <- tibble(variable = "qxs", commodity = "c_Bev", exporter = "Canada", importer = "USA", value = -50)
  weights <- tibble(sector = "FOD", commodity = c("c_Bev", "c_Food"), exporter = "Canada",
                    importer = "USA", value = c(1, 3))
  conv <- convert_gtap_shocks(shocks, weights, theta = c(FOD = 4))
  expect_equal(conv$cells$change, -0.125)
  expect_equal(conv$cells$factor, 0.875^(-1 / 4))
  expect_equal(conv$cells$factor^(-4), 0.875)
})

test_that("shocks between regions that are all in ROW are dropped", {
  shocks <- tibble(variable = "tms", commodity = "c", exporter = c("China", "Canada"),
                   importer = c("EU", "USA"), value = 10)
  weights <- tibble(sector = "BMT", commodity = "c", exporter = c("China", "Canada"),
                    importer = c("EU", "USA"), value = 1)
  conv <- convert_gtap_shocks(shocks, weights, theta = c(BMT = 8))
  expect_equal(nrow(conv$dropped), 1)
  expect_equal(conv$cells$rate, 0.10)
})

test_that("the generated scenario file reproduces the converted shocks", {
  shocks <- tibble(variable = c("tms", "tms", "qxs"), commodity = c("c_Steel", "c_Autos", "c_Bev"),
                   exporter = c("Canada", "USA", "Canada"), importer = c("USA", "Canada", "USA"),
                   value = c(25, 10, -40))
  weights <- tibble(sector = c("BMT", "MTV", "FOD"), commodity = c("c_Steel", "c_Autos", "c_Bev"),
                    exporter = c("Canada", "USA", "Canada"), importer = c("USA", "Canada", "USA"), value = 1)
  conv <- convert_gtap_shocks(shocks, weights, theta = c(BMT = 8, MTV = 3, FOD = 3.5))
  f <- tempfile(fileext = ".yml")
  write_gtap_scenario(conv, f, list(list(id = "a", label = "A", tariff_treatment = "ad_valorem"),
                                    list(id = "b", label = "B", migration_elasticity = 0)))
  sc <- load_scenarios(list(), f)
  expect_equal(names(sc), c("a", "b"))
  expect_identical(sc$a$shocks, sc$b$shocks)
  cfg <- list(regions = list(domestic = c("ON", "QC"), foreign = c("USA", "ROW")),
              sectors = list(scheme = "base37"), migration = list(elasticity = 0))
  regions <- c("ON", "QC", "USA", "ROW")
  sectors <- load_base_sectors()$sector_id
  dn <- list(dest = regions, origin = regions, sector = sectors)
  base <- list(regions = regions, sectors = sectors, domestic = c("ON", "QC"),
               pi = array(0.25, c(4, 4, length(sectors)), dn), tariff = array(0, c(4, 4, length(sectors)), dn))
  sh <- build_shocks(sc$a, base, cfg)
  expect_equal(sh$tariff_new["USA", "ON", "BMT"], 0.25)
  expect_equal(sh$tariff_new["QC", "USA", "MTV"], 0.10)
  expect_equal(sh$tau_hat["USA", "QC", "FOD"], 0.6^(-1 / 3.5), tolerance = 1e-6)
  expect_equal(sh$tariff_new["ON", "QC", "BMT"], 0)
})
