# Synthetic gravity data: pi[n, i] proportional to (tau[n, i] c[i])^-theta.
synthetic_gravity_panel <- function(tau, cost, theta, years = 2020) {
  regions <- rownames(tau)
  rows <- list()
  for (y in years) {
    for (n in regions) {
      v <- unname((tau[n, ] * cost)^(-theta))
      rows[[paste(y, n)]] <- tibble(year = y, origin = regions, dest = n, sector = "S1",
                                    value = 1000 * v / sum(v))
    }
  }
  bind_rows(rows)
}

test_that("the Head-Ries index recovers symmetric trade costs exactly", {
  regions <- c("A", "B", "C", "D")
  tau <- matrix(c(1, 1.3, 1.6, 2.0,
                  1.3, 1, 1.4, 1.7,
                  1.6, 1.4, 1, 1.2,
                  2.0, 1.7, 1.2, 1), 4, dimnames = list(regions, regions))
  panel <- synthetic_gravity_panel(tau, cost = c(1, 1.1, 0.9, 1.05), theta = 6)
  hr <- head_ries(expenditure_shares(panel), c(S1 = 6))
  expect_equal(nrow(hr), 12)
  expect_equal(hr$tau_bar, tau[cbind(hr$dest, hr$origin)], tolerance = 1e-12)
})

test_that("the Head-Ries index is the geometric mean of asymmetric costs", {
  regions <- c("A", "B", "C")
  tau <- matrix(c(1, 1.5, 1.2,
                  1.1, 1, 1.8,
                  1.4, 1.3, 1), 3, byrow = TRUE, dimnames = list(regions, regions))
  panel <- synthetic_gravity_panel(tau, cost = c(1, 1, 1), theta = 4)
  hr <- head_ries(expenditure_shares(panel), c(S1 = 4))
  expected <- sqrt(tau[cbind(hr$dest, hr$origin)] * tau[cbind(hr$origin, hr$dest)])
  expect_equal(hr$tau_bar, expected, tolerance = 1e-12)
})

test_that("the gravity regression recovers distance and adjacency effects", {
  set.seed(1)
  regions <- c("NL", "PE", "NS", "NB", "QC", "ON", "MB", "SK", "AB", "BC")
  cfg <- list(regions = list(domestic = regions),
              trade_costs = list(regressors = c("log_dist", "adjacent"), exclude_sectors = character(0),
                                 min_observations = 10),
              years = list(target = 2021))
  adj <- adjacency_function()
  dist <- tidyr::expand_grid(origin = regions, dest = regions) |>
    mutate(distance_normalized = if_else(origin == dest, 1, exp(stats::runif(n(), 1, 3.5))),
           adjacent = adj(origin, dest))
  # Symmetric distances
  dist <- dist |>
    left_join(dist |> select(origin = dest, dest = origin, d2 = distance_normalized),
              by = c("origin", "dest")) |>
    mutate(distance_normalized = if_else(origin < dest, distance_normalized, d2)) |>
    select(-d2)
  b <- 0.3
  c_adj <- -0.1
  hr <- tidyr::expand_grid(year = 2020:2021, origin = regions, dest = regions) |>
    filter(origin != dest) |>
    left_join(dist, by = c("origin", "dest")) |>
    mutate(sector = "S1", theta = 5,
           tau_bar = exp(b * log(distance_normalized) + c_adj * adjacent +
                           0.05 * (origin %in% c("QC", "ON")))) |>
    select(year, origin, dest, sector, theta, tau_bar)
  g <- suppressWarnings(estimate_gravity(cfg, hr, dist))  # exact synthetic data: perfect fit
  est <- setNames(g$coefficients$estimate, g$coefficients$term)
  expect_equal(unname(est["log_dist"]), b, tolerance = 1e-8)
  expect_equal(unname(est["adjacent"]), c_adj, tolerance = 1e-8)

  costs <- decompose_trade_costs(cfg, g, hr |> filter(year == 2021), dist)
  expect_true(all(costs$year == 2021))
  expect_equal(costs$tau_geo, exp(b * log(costs$distance_normalized) + c_adj * costs$adjacent),
               tolerance = 1e-8)
  expect_true(all(costs$tau_hat_nongeo <= 1 & costs$tau_hat_all <= 1))
  expect_equal(costs$tau_hat_nongeo, pmin(costs$tau_geo / costs$tau_bar, 1), tolerance = 1e-12)
})

test_that("pairs without distances stay in the decomposition but not in the regression", {
  set.seed(2)
  regions <- c("NS", "NB", "QC", "ON", "MB", "SK", "AB", "BC", "YT")
  cfg <- list(regions = list(domestic = regions),
              trade_costs = list(regressors = c("log_dist", "adjacent"), exclude_sectors = character(0),
                                 min_observations = 10),
              years = list(target = 2021))
  adj <- adjacency_function()
  dist <- tidyr::expand_grid(origin = regions, dest = regions) |>
    filter(origin != "YT", dest != "YT") |>
    mutate(distance_normalized = if_else(origin == dest, 1, exp(stats::runif(n(), 1, 3.5))),
           adjacent = adj(origin, dest))
  hr <- tidyr::expand_grid(year = 2021, origin = regions, dest = regions) |>
    filter(origin != dest) |>
    mutate(sector = "S1", theta = 5, tau_bar = exp(stats::runif(n(), 0.1, 1)))
  g <- estimate_gravity(cfg, hr, dist)
  expect_equal(g$coefficients$n_obs[1], sum(hr$origin != "YT" & hr$dest != "YT"))

  costs <- decompose_trade_costs(cfg, g, hr, dist)
  yt <- costs |> filter(origin == "YT" | dest == "YT")
  expect_equal(nrow(yt), 2 * (length(regions) - 1))
  expect_true(all(is.na(yt$tau_geo)))
  expect_true(all(yt$tau_hat_nongeo == 1))
  expect_equal(yt$tau_hat_all, 1 / yt$tau_bar)
  expect_equal(yt$tau_hat_measured_10, (1 + 0.9 * (yt$tau_bar - 1)) / yt$tau_bar)
})

test_that("exporter-specific costs are recovered from flows (Waugh, 2010)", {
  regions <- c("NL", "NS", "NB", "QC", "ON", "MB", "SK", "AB", "BC")
  set.seed(3)
  log_t <- setNames(stats::rnorm(length(regions), 0, 0.2), regions)
  size <- setNames(stats::rnorm(length(regions)), regions)
  theta <- c(S1 = 5)
  delta <- 0.3
  dist <- tidyr::expand_grid(origin = regions, dest = regions) |>
    mutate(distance_normalized = if_else(origin == dest, 1, exp(stats::runif(n(), 1, 3))), adjacent = 0L)
  dist <- dist |>
    left_join(dist |> select(origin = dest, dest = origin, d2 = distance_normalized), by = c("origin", "dest")) |>
    mutate(distance_normalized = if_else(origin < dest, distance_normalized, d2)) |> select(-d2)
  # tau[n, i] = d^delta t[i] off the diagonal, 1 on it.
  panel <- dist |>
    mutate(year = 2021L, sector = "S1",
           log_tau = if_else(origin == dest, 0, delta * log(distance_normalized) + unname(log_t[origin])),
           value = exp(unname(size[origin]) - theta[["S1"]] * log_tau)) |>
    select(year, origin, dest, sector, value)
  cfg <- list(regions = list(domestic = regions),
              trade_costs = list(regressors = c("log_dist"), exclude_sectors = character(0),
                                 min_observations = 10, measured_index = "augmented"),
              years = list(target = 2021))
  asym <- suppressWarnings(estimate_asymmetries(cfg, panel, theta, dist))
  expect_equal(asym$log_t[match(regions, asym$region)], unname(log_t - mean(log_t)), tolerance = 1e-8)

  # Pooled years with year-specific fixed effects (aliased levels are normalized).
  panel2 <- bind_rows(panel, panel |> mutate(year = 2022L, value = value * exp(0.3 * (origin == "ON"))))
  asym2 <- suppressWarnings(estimate_asymmetries(cfg, panel2, theta, dist))
  for (y in c(2021L, 2022L)) {
    a <- asym2 |> filter(year == y)
    expect_equal(a$log_t[match(regions, a$region)], unname(log_t - mean(log_t)), tolerance = 1e-8)
  }

  hr <- head_ries(expenditure_shares(panel), theta)
  g <- suppressWarnings(estimate_gravity(cfg, hr, dist))
  costs <- decompose_trade_costs(cfg, g, hr, dist, asym)
  true_tau <- exp(delta * log(costs$distance_normalized) + log_t[costs$origin])
  expect_equal(costs$tau_tilde, unname(true_tau), tolerance = 1e-8)  # directional cost
  expect_equal(costs$tau_index, costs$tau_tilde)
  expect_equal(costs$tau_hat_asym, unname(pmin(1, exp(log_t[costs$dest] - log_t[costs$origin]))),
               tolerance = 1e-8)
})

test_that("the level-distance specification with an interprovincial indicator is recovered", {
  # Alvarez, Krznar and Tombe (2019): distance in thousands of km, adjacency and
  # an interprovincial indicator by year, on interprovincial and international pairs.
  set.seed(4)
  dom <- c("NS", "NB", "QC", "ON", "MB", "SK", "AB", "BC")
  regions <- c(dom, "USA", "ROW")
  adj <- adjacency_function()
  dist <- tidyr::expand_grid(origin = regions, dest = regions) |>
    mutate(distance_km = if_else(origin == dest, 100, stats::runif(n(), 300, 6000)),
           distance_normalized = distance_km / 100, adjacent = adj(origin, dest))
  dist <- dist |>
    left_join(dist |> select(origin = dest, dest = origin, d2 = distance_km), by = c("origin", "dest")) |>
    mutate(distance_km = if_else(origin < dest, distance_km, d2)) |> select(-d2)
  a1 <- 0.08
  a2 <- -0.15
  border <- c(`2020` = 0.2, `2021` = 0.25)
  fe <- setNames(stats::rnorm(length(regions), 0, 0.1), regions)
  hr <- tidyr::expand_grid(year = 2020:2021, origin = regions, dest = regions) |>
    filter(origin != dest) |>
    left_join(dist, by = c("origin", "dest")) |>
    mutate(sector = "S1", theta = 5,
           ip = as.integer(origin %in% dom & dest %in% dom),
           tau_bar = exp(a1 * distance_km / 1000 + a2 * adjacent + border[as.character(year)] * ip +
                           fe[origin] + fe[dest])) |>
    select(year, origin, dest, sector, theta, tau_bar)
  cfg <- list(regions = list(domestic = dom),
              trade_costs = list(sample = "all", regressors = c("dist_1000km", "adjacent", "interprovincial"),
                                 year_interactions = "interprovincial", exclude_sectors = character(0),
                                 min_observations = 10),
              years = list(target = 2021))
  g <- suppressWarnings(estimate_gravity(cfg, hr, dist))
  est <- setNames(g$coefficients$estimate, g$coefficients$term)
  expect_equal(unname(est["dist_1000km"]), a1, tolerance = 1e-8)
  expect_equal(unname(est["adjacent"]), a2, tolerance = 1e-8)
  expect_equal(unname(est["interprovincial:factor(year)2021"]), 0.25, tolerance = 1e-8)
  costs <- decompose_trade_costs(cfg, g, hr |> filter(year == 2021), dist)
  expect_equal(costs$tau_geo, exp(a1 * costs$distance_km / 1000 + a2 * costs$adjacent), tolerance = 1e-8)
  expect_setequal(unique(costs$pair_type), c("interprovincial", "international", "foreign"))
})

test_that("trade-cost summaries are trade-weighted averages", {
  costs <- tibble(origin = c("A", "B"), dest = c("B", "A"), sector = "S1", pair_type = "interprovincial",
                  tau_bar = c(1.5, 1.5), tau_geo = c(1.2, 1.2), log_t_origin = c(0.1, -0.1),
                  log_t_dest = c(-0.1, 0.1))
  flows <- tibble(origin = c("A", "B"), dest = c("B", "A"), sector = "S1", value = c(3, 1))
  s <- summarise_trade_costs(costs, flows)
  expect_equal(s$measured_cost, 50)
  expect_equal(s$geography, 20)
  expect_equal(s$nongeography, 30)
  expect_equal(s$nondistance_contribution, 25)
  expect_equal(s$asymmetry_contribution, 100 * 0.75 * (exp(0.2) - 1))
})

test_that("geographic costs are floored at within-region costs unless disabled", {
  # A negative distance effect makes tau_geo < 1; eliminating non-geographic
  # costs must then not cut more than eliminating all measured costs.
  regions <- c("NS", "NB", "QC", "ON", "MB", "SK", "AB", "BC")
  set.seed(5)
  dist <- tidyr::expand_grid(origin = regions, dest = regions) |>
    mutate(distance_normalized = if_else(origin == dest, 1, exp(stats::runif(n(), 1, 3))), adjacent = 0L)
  hr <- dist |> filter(origin != dest) |>
    mutate(year = 2021, sector = "S1", theta = 5,
           tau_bar = exp(-0.1 * log(distance_normalized) + 0.6 + stats::rnorm(n(), 0, 0.01))) |>
    select(year, origin, dest, sector, theta, tau_bar)
  cfg <- list(regions = list(domestic = regions),
              trade_costs = list(regressors = "log_dist", exclude_sectors = character(0), min_observations = 10),
              years = list(target = 2021))
  g <- estimate_gravity(cfg, hr, dist)
  expect_lt(g$coefficients$estimate, 0)
  costs <- decompose_trade_costs(cfg, g, hr, dist)
  expect_true(all(costs$tau_geo < 1))
  expect_equal(costs$tau_hat_nongeo, costs$tau_hat_all)
  cfg$trade_costs$floor_geographic <- FALSE
  costs <- decompose_trade_costs(cfg, g, hr, dist)
  expect_equal(costs$tau_hat_nongeo, pmin(costs$tau_geo / costs$tau_bar, 1))
  expect_true(all(costs$tau_hat_nongeo < costs$tau_hat_all))
})

test_that("within-region pairs enter with an intra-regional indicator by year", {
  set.seed(6)
  dom <- c("NS", "NB", "QC", "ON", "MB", "SK", "AB", "BC")
  regions <- c(dom, "USA", "ROW")
  adj <- adjacency_function()
  dist <- tidyr::expand_grid(origin = regions, dest = regions) |>
    mutate(distance_km = stats::runif(n(), 300, 6000), distance_normalized = distance_km / 100,
           adjacent = adj(origin, dest))
  dist <- dist |>
    left_join(dist |> select(origin = dest, dest = origin, d2 = distance_km), by = c("origin", "dest")) |>
    mutate(distance_km = if_else(origin < dest, distance_km, d2)) |> select(-d2)
  # Fixed effects with f_o(n) + f_d(n) = -c for every region, so that the
  # within-region observations (log cost 0) are fitted exactly by intra = c.
  f <- setNames(stats::rnorm(length(regions)), regions)
  c0 <- 0.4
  hr <- tidyr::expand_grid(year = 2020:2021, origin = regions, dest = regions) |>
    filter(origin != dest) |>
    left_join(dist, by = c("origin", "dest")) |>
    mutate(sector = "S1", theta = 5,
           tau_bar = exp(0.07 * distance_km / 1000 - 0.1 * adjacent + f[origin] - c0 - f[dest] -
                           0.3 * (origin %in% dom & dest %in% dom))) |>
    select(year, origin, dest, sector, theta, tau_bar)
  cfg <- list(regions = list(domestic = dom),
              trade_costs = list(sample = "all", regressors = c("dist_1000km", "adjacent", "interprovincial"),
                                 year_interactions = "interprovincial", own_pairs = TRUE,
                                 exclude_sectors = character(0), min_observations = 10),
              years = list(target = 2021))
  g <- suppressWarnings(estimate_gravity(cfg, hr, dist))
  est <- setNames(g$coefficients$estimate, g$coefficients$term)
  expect_equal(unname(est[c("dist_1000km", "adjacent")]), c(0.07, -0.1), tolerance = 1e-8)
  intra_2021 <- est[grepl("intra", names(est)) & grepl("2021", names(est))]
  expect_equal(unname(intra_2021), c0, tolerance = 1e-8)
  expect_equal(sum(g$data$intra), 2 * length(regions))
})
