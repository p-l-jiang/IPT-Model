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

  costs <- decompose_trade_costs(cfg, g)
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

  costs <- decompose_trade_costs(cfg, g)
  yt <- costs |> filter(origin == "YT" | dest == "YT")
  expect_equal(nrow(yt), 2 * (length(regions) - 1))
  expect_true(all(is.na(yt$tau_geo)))
  expect_true(all(yt$tau_hat_nongeo == 1))
  expect_equal(yt$tau_hat_all, 1 / yt$tau_bar)
  expect_equal(yt$tau_hat_measured_10, (1 + 0.9 * (yt$tau_bar - 1)) / yt$tau_bar)
})
