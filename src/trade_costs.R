# Measured trade costs and their decomposition.
#
# Head and Ries (2001) index of bilateral trade costs relative to internal
# trade costs, by sector:
#   tau_bar[n, i, j] = ((pi[n, n, j] pi[i, i, j]) / (pi[n, i, j] pi[i, n, j]))^(1 / (2 theta[j]))
# The index is symmetric and is defined only when all four shares are positive.
#
# Decomposition (Albrecht and Tombe, 2016): for each sector,
#   log tau_bar[n, i] = b log(d[n, i] / sqrt(d[n, n] d[i, i])) + c adjacent[n, i]
#                       + mu[n, year] + nu[i, year] + e[n, i, year],
# estimated by OLS on interprovincial pairs (n != i) pooled over the panel
# years, with standard errors clustered by origin and destination. The
# geographic component is tau_geo = exp(b log d_norm + c adjacent); the
# remainder tau_bar / tau_geo is the non-geographic barrier. Because distance is
# normalized by internal distances, tau_geo does not depend on the units of
# distance (the legacy code used distance in km, in levels).

#' Expenditure shares pi[n, i, j] from a long flow panel.
#'
#' Only destinations whose total purchases are fully observed should be used;
#' see trade_cost_panel().
expenditure_shares <- function(panel) {
  panel |>
    group_by(year, dest, sector) |>
    mutate(pi = value / sum(value)) |>
    ungroup()
}

#' Head-Ries measured trade costs for all pairs with two-way trade.
#'
#' @param shares Output of expenditure_shares().
#' @param theta Named trade elasticities.
#' @return Tibble: year, origin, dest, sector, pi_ni, pi_in, pi_nn, pi_ii, tau_bar.
head_ries <- function(shares, theta) {
  own <- shares |> filter(origin == dest) |> select(year, region = dest, sector, pi_own = pi)
  shares |>
    filter(origin != dest) |>
    select(year, origin, dest, sector, pi_ni = pi) |>
    inner_join(shares |> filter(origin != dest) |>
                 select(year, origin = dest, dest = origin, sector, pi_in = pi),
               by = c("year", "origin", "dest", "sector")) |>
    inner_join(own |> rename(dest = region, pi_nn = pi_own), by = c("year", "dest", "sector")) |>
    inner_join(own |> rename(origin = region, pi_ii = pi_own), by = c("year", "origin", "sector")) |>
    mutate(theta = unname(theta[sector]),
           tau_bar = ((pi_nn * pi_ii) / (pi_ni * pi_in))^(1 / (2 * theta))) |>
    filter(is.finite(tau_bar), tau_bar > 0)
}

#' Measured trade costs for the regions/years used in estimation.
#'
#' Interprovincial pairs only need Canadian destinations, whose purchases from
#' all origins are observed in every panel year. When the sample includes
#' international pairs, only years with ICIO data are used.
trade_cost_panel <- function(cfg, panel, theta) {
  dom <- cfg$regions$domestic
  if (identical(cfg$trade_costs$sample, "all")) {
    panel <- panel |> filter(year %in% complete_years(panel))
    return(head_ries(expenditure_shares(panel), theta))
  }
  shares <- expenditure_shares(panel |> filter(dest %in% dom))
  head_ries(shares, theta) |> filter(origin %in% dom, dest %in% dom)
}

#' Fixed-effect gravity regressions of log measured trade costs, by sector.
#'
#' @return List with `coefficients` (sector, term, estimate, std_error, n_obs)
#'   and `data` (estimation sample with distances).
estimate_gravity <- function(cfg, hr, distances) {
  spec <- cfg$trade_costs
  dom <- cfg$regions$domestic
  # Pairs without distance data (e.g. Yukon when the census extract lacks it)
  # are kept in `data`, so that scenarios based on measured costs alone still
  # apply to them, but cannot enter the regressions.
  dat <- hr |>
    left_join(distances |> select(origin, dest, distance_normalized, adjacent),
              by = c("origin", "dest")) |>
    mutate(log_tau = log(tau_bar),
           log_dist = if_else(distance_normalized > 0, log(distance_normalized), NA_real_),
           border = as.integer(xor(origin %in% dom, dest %in% dom)),
           origin_year = interaction(origin, year, drop = TRUE),
           dest_year = interaction(dest, year, drop = TRUE))
  excluded <- spec$exclude_sectors %||% character(0)
  regressors <- spec$regressors %||% c("log_dist", "adjacent")
  if (identical(spec$sample, "all")) regressors <- union(regressors, "border")
  min_obs <- spec$min_observations %||% 20

  rows <- list()
  for (s in setdiff(unique(dat$sector), excluded)) {
    d <- dat |> filter(sector == s)
    d <- d[stats::complete.cases(d[, regressors]), ]
    if (nrow(d) < min_obs) next
    terms <- regressors[vapply(regressors, function(v) length(unique(d[[v]])) > 1, logical(1))]
    fe <- if (length(unique(d$year)) > 1) "origin_year + dest_year" else "origin + dest"
    f <- stats::as.formula(paste("log_tau ~", paste(terms, collapse = " + "), "+", fe))
    fit <- stats::lm(f, data = d)
    vc <- sandwich::vcovCL(fit, cluster = ~ origin + dest, fix = TRUE)
    est <- stats::coef(fit)[terms]
    se <- sqrt(diag(vc)[terms])
    rows[[s]] <- tibble(sector = s, term = terms, estimate = unname(est),
                        std_error = unname(se), n_obs = nrow(d))
  }
  list(coefficients = bind_rows(rows), data = dat)
}

#' Decompose target-year measured trade costs into geographic and
#' non-geographic components.
#'
#' @return Tibble for interprovincial pairs in the target year with tau_bar,
#'   tau_geo, tau_nongeo and the counterfactual changes used by the Table 6
#'   scenarios:
#'   tau_hat_measured_10   10% lower measured costs: (1 + 0.9 (tau_bar - 1)) / tau_bar
#'   tau_hat_nongeo        eliminate non-geographic costs: min(tau_geo / tau_bar, 1)
#'   tau_hat_all           eliminate all measured costs: min(1 / tau_bar, 1)
decompose_trade_costs <- function(cfg, gravity) {
  coefs <- gravity$coefficients |>
    select(sector, term, estimate) |>
    tidyr::pivot_wider(names_from = term, values_from = estimate)
  if (!"adjacent" %in% names(coefs)) coefs$adjacent <- 0
  dom <- cfg$regions$domestic
  gravity$data |>
    filter(year == cfg$years$target, origin %in% dom, dest %in% dom) |>
    left_join(coefs |> select(sector, b_dist = log_dist, b_adj = adjacent), by = "sector") |>
    mutate(
      b_adj = coalesce(b_adj, 0),
      tau_geo = exp(b_dist * log_dist + b_adj * adjacent),
      tau_nongeo = tau_bar / tau_geo,
      tau_hat_measured_10 = if_else(tau_bar > 1, (1 + 0.9 * (tau_bar - 1)) / tau_bar, 1),
      tau_hat_nongeo = if_else(is.na(tau_geo), 1, pmin(tau_geo / tau_bar, 1)),
      tau_hat_all = pmin(1 / tau_bar, 1)
    ) |>
    select(year, origin, dest, sector, theta, tau_bar, tau_geo, tau_nongeo,
           tau_hat_measured_10, tau_hat_nongeo, tau_hat_all, distance_normalized, adjacent)
}
