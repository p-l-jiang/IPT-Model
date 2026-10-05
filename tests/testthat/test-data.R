test_that("haversine distances are correct", {
  # One degree of longitude at the equator with the WGS84 equatorial radius.
  expect_equal(haversine_km(0, 0, 1, 0), 2 * pi * 6378.137 / 360, tolerance = 1e-9)
  expect_equal(haversine_km(-79.38, 43.65, -79.38, 43.65), 0)
  # Toronto - Montreal is about 504 km.
  expect_equal(haversine_km(-79.3832, 43.6532, -73.5673, 45.5017), 504, tolerance = 0.01)
})

test_that("census points are parsed as numbers and provinces by PRUID", {
  f <- tempfile(fileext = ".csv")
  # Mimics a Geographic Attribute File: a non-numeric population entry would
  # turn the column into a factor under read.csv(stringsAsFactors = TRUE).
  writeLines(c("PRUID,PRNAME,DALAT,DALONG,DBPOP2006",
               "60,Yukon Territory,60.72,-135.05,1200",
               "60,Yukon Territory,60.70,-135.10,800",
               "35,Ontario,43.65,-79.38,..",
               "35,Ontario,43.70,-79.40,5",
               "35,Ontario,45.42,-75.69,15"), f)
  da <- read_da_points(f)
  expect_equal(da$region, c("YT", "YT", "ON", "ON"))
  expect_equal(da$population, c(1200, 800, 5, 15))
  geo <- region_geography(da)
  expect_equal(geo$lat[geo$region == "YT"], (60.72 * 1200 + 60.70 * 800) / 2000)
  expect_equal(geo$population[geo$region == "ON"], 20)
})

test_that("distance matrices are symmetric with normalized internal distance of one", {
  da <- tibble(region = c("AB", "AB", "BC", "BC", "SK"),
               lat = c(51.0, 53.5, 49.3, 48.4, 50.4),
               lon = c(-114.1, -113.5, -123.1, -123.4, -104.6),
               population = c(10, 8, 20, 4, 3))
  d <- distance_matrix(region_geography(da))
  m <- d |> select(origin, dest, distance_km) |>
    tidyr::pivot_wider(names_from = dest, values_from = distance_km) |>
    tibble::column_to_rownames("origin") |> as.matrix()
  expect_equal(m, t(m)[rownames(m), colnames(m)])
  expect_equal(d$distance_normalized[d$origin == d$dest], rep(1, 3))
  expect_equal(d$adjacent[d$origin == "AB" & d$dest == "BC"], 1)
  expect_equal(d$adjacent[d$origin == "BC" & d$dest == "SK"], 0)
})

test_that("ICIO aggregation keeps China/Mexico split rows in ROW and conserves totals", {
  cfg <- list(regions = list(foreign = c("USA", "ROW")), sectors = list(scheme = "base37"))
  rows <- c(paste0(rep(c("CAN", "USA", "CN1", "CHN"), each = 2), "_", c("A01", "C29")))
  fd <- c("CAN_HFCE", "USA_HFCE", "CHN_HFCE", "CHN_GFCF")
  set.seed(1)
  z <- matrix(stats::runif(length(rows)^2), length(rows), dimnames = list(rows, rows))
  z[grepl("^CHN_", rows), ] <- 0  # as in the extended ICIO: CHN rows are empty
  z[, grepl("^CHN_", rows)] <- 0
  f <- matrix(stats::runif(length(rows) * length(fd)), length(rows), dimnames = list(rows, fd))
  f[grepl("^CHN_", rows), ] <- 0
  out <- rowSums(z) + rowSums(f)
  va <- out - colSums(z)
  m <- rbind(cbind(z, f, OUT = out), TLS = 0, VA = c(va, rep(0, length(fd) + 1)),
             OUT = c(out, rep(0, length(fd) + 1)))
  agg <- aggregate_icio(m, cfg)
  expect_setequal(unique(agg$flows$origin), c("CAN", "USA", "ROW"))
  expect_equal(sum(agg$flows$value), sum(z) + sum(f))
  # CN1 output is attributed to the rest of the world.
  cn1_out <- sum(out[grepl("^CN1_", rows)])
  expect_equal(sum(agg$production$output[agg$production$region == "ROW"]), cn1_out)
  expect_equal(sum(agg$production$va), sum(va))
  expect_equal(sort(unique(agg$production$sector)), c("AGR", "MTV"))
})

test_that("annual exchange rates flag partial years", {
  fx <- load_fx(list(paths = list(fx_file = file.path(ipt_root(), "data", "raw", "fx", "FXUSDCAD.csv"))))
  expect_true(fx$partial[fx$year == 2007])
  expect_equal(fx_rate(fx, 2022), 1.3013, tolerance = 1e-3)
  expect_error(fx_rate(fx, 2007), "cover only")
})

test_that("BoC-rule trade elasticities follow the documented rule", {
  te <- list(source_table = file.path(ipt_root(), "config", "parameters", "boc2018_trade_elasticities.csv"),
             components = file.path(ipt_root(), "config", "parameters", "theta_components_base37.csv"),
             significance_z = 1.96, adjustment = 2, services_theta = 5)
  tab <- derive_boc_elasticities(te)
  th <- setNames(tab$theta, tab$sector_id)
  expect_equal(unname(th[c("AGR", "MIE", "MIN", "MIS", "FOD", "TEX", "WOD", "PAP", "PET", "CHM",
                           "ELC", "ELQ", "MTV", "OTE", "TRD")]),
               c(3.1, 20.2, 45.0, 7.0, 3.5, 7.6, 17.8, 10.7, 71.1, 6.8, 11.8, 14.3, 3.0, 10.7, 7.0))
})

test_that("configuration validation rejects YAML booleans in region lists", {
  cfg <- load_config(file.path(ipt_root(), "config", "default.yml"))
  expect_true("ON" %in% cfg$regions$domestic)
  cfg$regions$domestic[6] <- TRUE
  expect_error(validate_config(cfg), "quote them")
})

test_that("configuration overrides set nested values parsed as YAML", {
  cfg <- load_config(file.path(ipt_root(), "config", "default.yml"),
                     c("migration.elasticity=1.5", 'regions.foreign=["ROW"]', "name=variant",
                       "trade_costs.regressors=[dist_1000km, adjacent]"))
  expect_equal(cfg$migration$elasticity, 1.5)
  expect_equal(cfg$regions$foreign, "ROW")
  expect_equal(cfg$paths$output, "output/variant")
  expect_equal(cfg$trade_costs$regressors, c("dist_1000km", "adjacent"))
  expect_error(set_config_value(cfg, "novalue"), "key.subkey=value")
})

test_that("uniform trade elasticities distinguish goods and services", {
  cfg <- load_config(file.path(ipt_root(), "config", "default.yml"),
                     c("trade_elasticities.method=uniform", "trade_elasticities.goods_theta=6.5",
                       "trade_elasticities.services_theta=5"))
  th <- load_trade_elasticities(cfg)
  expect_equal(unname(th[c("MTV", "FOD", "FIN", "TRD")]), c(6.5, 6.5, 5, 5))
})

test_that("published sector values replace phi and beta in the chosen regions only", {
  phi <- matrix(0.5, 3, 2, dimnames = list(c("ON", "QC", "ROW"), c("S1", "S2")))
  beta <- matrix(0.5, 3, 2, dimnames = dimnames(phi))
  v <- tibble::tibble(sector_id = c("S2", "S1"), phi = c(0.3, 0.6), beta = c(0.3, 0.9))
  out <- apply_sector_values(phi, beta, v, c("ON", "QC"))
  expect_equal(unname(out$phi["QC", ]), c(0.6, 0.3))
  expect_equal(unname(out$beta["ON", ]), c(0.75, 0.25))
  expect_equal(unname(out$phi["ROW", ]), c(0.5, 0.5))
  expect_error(apply_sector_values(phi, beta, v[1, ], "ON"), "lack sectors: S1")
})

test_that("measurement elasticities replace the model's for the listed sectors only", {
  f <- tempfile(fileext = ".csv")
  readr::write_csv(tibble::tibble(sector_id = "FOD", theta = 3.5), f)
  theta <- c(FOD = 2.5, FIN = 5)
  cfg <- list(trade_costs = list(measurement_elasticities = f))
  expect_equal(measurement_elasticities(cfg, theta), c(FOD = 3.5, FIN = 5))
  expect_equal(measurement_elasticities(list(trade_costs = list()), theta), theta)
  readr::write_csv(tibble::tibble(sector_id = "XXX", theta = 3.5), f)
  expect_error(measurement_elasticities(cfg, theta), "unknown sectors: XXX")
})

test_that("pairwise distances are population-weighted means over pairs of residents", {
  da <- tibble::tibble(region = c("A", "A", "B", "B"), lon = c(0, 0, 2, 2), lat = c(0, 1, 0, 1),
                       population = c(1, 3, 2, 2))
  D <- pairwise_distances(da, cell = 0.01)
  d01 <- haversine_km(0, 0, 0, 1)
  expect_equal(D["A", "A"], 2 * 0.25 * 0.75 * d01)
  expect_equal(D["B", "B"], 2 * 0.5 * 0.5 * d01)
  cross <- 0.25 * 0.5 * (haversine_km(0, 0, 2, 0) + haversine_km(0, 0, 2, 1)) +
    0.75 * 0.5 * (haversine_km(0, 1, 2, 0) + haversine_km(0, 1, 2, 1))
  expect_equal(D["A", "B"], cross)
  expect_equal(D["B", "A"], cross)
})
