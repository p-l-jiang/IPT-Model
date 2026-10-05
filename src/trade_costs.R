# Measured trade costs and their decomposition.
#
# Head and Ries (2001) index of bilateral trade costs relative to internal
# trade costs, by sector:
#   tau_bar[n, i, j] = ((pi[n, n, j] pi[i, i, j]) / (pi[n, i, j] pi[i, n, j]))^(1 / (2 theta[j]))
# The index is symmetric and is defined only when all four shares are positive.
#
# Geographic decomposition. For each sector,
#   log tau_bar[n, i] = sum_k b_k x_k[n, i] + mu[n, year] + nu[i, year] + e[n, i, year],
# estimated by OLS pooled over the panel years, with standard errors clustered
# by origin and destination. The geographic component is
# tau_geo = exp(sum_k b_k x_k) over the geographic regressors; the remainder
# tau_bar / tau_geo (fixed effects, border indicators and residual) is the
# non-geographic barrier. Two specifications are supported (trade_costs$...):
#   * Albrecht and Tombe (2016): log(d[n, i] / sqrt(d[n, n] d[i, i])), the
#     distance between two regions relative to their internal distances
#     (regressor log_dist), optionally with an adjacency indicator, estimated
#     on interprovincial pairs. Because distance is normalized by internal
#     distances, tau_geo does not depend on the units of distance.
#   * Alvarez, Krznar and Tombe (2019): distance in thousands of km
#     (dist_1000km) and adjacency, estimated on interprovincial and
#     international pairs with an interprovincial-trade indicator by year.
# The two attribute very different shares of measured costs to geography (see
# docs/replication.md): log normalized distance rises steeply between internal
# and interprovincial distances and absorbs most of the jump in costs at
# provincial borders, distance in levels does not.
#
# Asymmetric costs (Waugh, 2010; Albrecht and Tombe, 2016, appendix B). With
# tau[n, i] = t_sym[n, i] t[i], where t[i] is an exporter-specific cost,
#   log(pi[n, i] / pi[n, n]) = g x[n, i] + iota[n] + eta[i] + e[n, i],
# estimated on interprovincial pairs, identifies log t[i] = -(iota[i] + eta[i]) / theta
# (with the intercept included in the fixed effects). Removing asymmetries
# lowers each cost to the cheaper direction: tau_hat[n, i] = min(1, t[n] / t[i]).
# The augmented index tau_tilde[n, i] = tau_bar[n, i] (t[i] / t[n])^(1/2) =
# tau[n, i] / sqrt(tau[n, n] tau[i, i]) measures directional costs.

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

#' Measured trade costs for every pair of regions in the calibration year
#' (whose flow matrix is complete), including international pairs.
target_year_costs <- function(cfg, panel, theta) {
  y <- cfg$years$target
  if (!y %in% complete_years(panel)) stopf("The flow panel has no complete flow matrix for %d.", y)
  head_ries(expenditure_shares(panel |> filter(year == y)), theta)
}

#' Gravity specification with defaults.
gravity_spec <- function(cfg) {
  tc <- cfg$trade_costs
  regressors <- tc$regressors %||% c("log_dist", "adjacent")
  if (identical(tc$sample, "all") && !any(c("border", "interprovincial") %in% regressors)) {
    regressors <- c(regressors, "border")
  }
  geographic_candidates <- c("log_dist", "dist_1000km", "adjacent")
  own_pairs <- isTRUE(tc$own_pairs)
  if (own_pairs) regressors <- union(regressors, "intra")
  list(sample = tc$sample %||% "interprovincial",
       regressors = regressors,
       geographic = tc$geographic %||% intersect(regressors, geographic_candidates),
       year_interactions = union(tc$year_interactions %||% character(0), if (own_pairs) "intra"),
       own_pairs = own_pairs,
       exclude = tc$exclude_sectors %||% character(0),
       min_obs = tc$min_observations %||% 20)
}

#' Within-region observations (log cost zero by construction) with an
#' intra-regional indicator, as in the regressions of Alvarez, Krznar and
#' Tombe (2019): one per region, sector and year present in the sample.
own_pair_rows <- function(hr) {
  hr |>
    distinct(year, sector, region = origin) |>
    bind_rows(hr |> distinct(year, sector, region = dest)) |>
    distinct() |>
    transmute(year, origin = region, dest = region, sector, tau_bar = 1)
}

#' Add pair-level regressors to a table with origin and dest columns.
#'
#' log_dist      log of distance relative to internal distances
#' dist_1000km   distance between population-weighted centres, thousands of km
#' adjacent      shared border or fixed link (config/concordances/adjacency.csv)
#' border        exactly one of the two regions is Canadian
#' interprovincial  two different Canadian regions
#' intra         within-region pair (only with trade_costs$own_pairs)
#' For within-region pairs distance in km is set to zero, as for a region's
#' population-weighted centre with itself.
pair_regressors <- function(dat, distances, cfg) {
  dom <- cfg$regions$domestic
  d <- distances
  if (!"distance_km" %in% names(d)) d$distance_km <- NA_real_
  dat |>
    left_join(d |> select(origin, dest, distance_normalized, distance_km, adjacent),
              by = c("origin", "dest")) |>
    mutate(log_dist = if_else(distance_normalized > 0, log(distance_normalized), NA_real_),
           dist_1000km = if_else(origin == dest, 0, distance_km / 1000),
           border = as.integer(xor(origin %in% dom, dest %in% dom)),
           interprovincial = as.integer(origin %in% dom & dest %in% dom & origin != dest),
           intra = as.integer(origin == dest))
}

#' Fixed-effect gravity regressions of log measured trade costs, by sector.
#'
#' Pairs without distance data are kept in `data` but cannot enter the
#' regressions.
#'
#' @return List with `coefficients` (sector, term, estimate, std_error, n_obs),
#'   `data` (estimation sample with regressors) and `spec`.
estimate_gravity <- function(cfg, hr, distances) {
  spec <- gravity_spec(cfg)
  if (spec$own_pairs) hr <- bind_rows(hr, own_pair_rows(hr))
  dat <- pair_regressors(hr, distances, cfg) |>
    mutate(log_tau = log(tau_bar),
           origin_year = interaction(origin, year, drop = TRUE),
           dest_year = interaction(dest, year, drop = TRUE))
  rows <- list()
  for (s in setdiff(unique(dat$sector), spec$exclude)) {
    d <- dat |> filter(sector == s)
    d <- d[stats::complete.cases(d[, spec$regressors]), ]
    if (nrow(d) < spec$min_obs) next
    multi_year <- length(unique(d$year)) > 1
    terms <- spec$regressors[vapply(spec$regressors, function(v) length(unique(d[[v]])) > 1, logical(1))]
    rhs <- ifelse(multi_year & terms %in% spec$year_interactions,
                  paste0(terms, ":factor(year)"), terms)
    fe <- if (multi_year) c("origin_year", "dest_year") else c("origin", "dest")
    fit <- stats::lm(stats::as.formula(paste("log_tau ~", paste(c(rhs, fe), collapse = " + "))), data = d)
    cf <- stats::coef(fit)
    keep <- names(cf)[!is.na(cf) & !grepl("^(\\(Intercept\\)|origin|dest)", names(cf))]
    vc <- sandwich::vcovCL(fit, cluster = ~ origin + dest, fix = TRUE)
    rows[[s]] <- tibble(sector = s, term = keep, estimate = unname(cf[keep]),
                        std_error = unname(sqrt(diag(vc)[keep])), n_obs = nrow(d))
  }
  list(coefficients = bind_rows(rows), data = dat, spec = spec)
}

#' Exporter-specific trade costs (log t[i]) by sector and year.
#'
#' Regresses log(pi[n, i] / pi[n, n]) on the geographic regressors of the
#' gravity specification with importer-year and exporter-year fixed effects,
#' on interprovincial pairs with positive flows. log t is normalized to mean
#' zero across regions within each sector and year (only ratios matter).
#'
#' @return Tibble: year, region, sector, log_t (NA-free; regions that are not
#'   both importer and exporter in a year are omitted).
estimate_asymmetries <- function(cfg, panel, theta, distances) {
  spec <- gravity_spec(cfg)
  dom <- cfg$regions$domestic
  shares <- expenditure_shares(panel |> filter(dest %in% dom))
  own <- shares |> filter(origin == dest) |> select(year, dest, sector, pi_nn = pi)
  dat <- shares |>
    filter(origin != dest, origin %in% dom, pi > 0) |>
    inner_join(own, by = c("year", "dest", "sector")) |>
    filter(pi_nn > 0) |>
    mutate(y = log(pi / pi_nn)) |>
    pair_regressors(distances, cfg) |>
    mutate(importer_fe = paste(dest, year, sep = "_"), exporter_fe = paste(origin, year, sep = "_"))
  regs <- spec$geographic
  out <- list()
  for (s in setdiff(unique(dat$sector), spec$exclude)) {
    d <- dat |> filter(sector == s)
    d <- d[stats::complete.cases(d[, regs]), ]
    if (nrow(d) < spec$min_obs) next
    terms <- regs[vapply(regs, function(v) length(unique(d[[v]])) > 1, logical(1))]
    fit <- stats::lm(stats::as.formula(paste("y ~", paste(c(terms, "importer_fe", "exporter_fe"),
                                                         collapse = " + "))), data = d)
    cf <- stats::coef(fit)
    cf[is.na(cf)] <- 0  # aliased levels: an innocuous normalization (see header)
    fe <- function(prefix, lev) {
      v <- cf[paste0(prefix, lev)]
      ifelse(is.na(v), 0, v)  # base level
    }
    both <- intersect(unique(d$importer_fe), unique(d$exporter_fe))
    total <- unname(cf["(Intercept)"]) + fe("importer_fe", both) + fe("exporter_fe", both)
    out[[s]] <- tibble(key = both, sector = s, log_t = -unname(total) / unname(theta[s])) |>
      tidyr::separate(key, c("region", "year"), sep = "_", convert = TRUE)
  }
  bind_rows(out) |>
    group_by(year, sector) |>
    mutate(log_t = log_t - mean(log_t)) |>
    ungroup() |>
    select(year, region, sector, log_t)
}

#' Decompose calibration-year measured trade costs.
#'
#' @param gravity Output of estimate_gravity().
#' @param hr_target Output of target_year_costs() (all pairs).
#' @param asymmetries Output of estimate_asymmetries() or NULL.
#' @return Tibble with one row per pair and sector (all pairs with two-way
#'   trade) and the counterfactual changes used by the measured-cost scenarios:
#'   tau_index            index used for measured costs: tau_bar, or tau_tilde
#'                        when trade_costs$measured_index is "augmented"
#'   tau_hat_measured_10  10% lower measured costs: (1 + 0.9 (index - 1)) / index
#'   tau_hat_nongeo       eliminate non-geographic costs: min(max(tau_geo, 1) / tau_bar, 1)
#'                        (without the floor at one if trade_costs$floor_geographic is false)
#'   tau_hat_asym         eliminate asymmetries: min(1, t[dest] / t[origin])
#'   tau_hat_all          eliminate all measured costs: min(1 / index, 1)
#'   tau_geo is estimated only for pair types in the gravity sample and is NA
#'   (no non-geographic shock) otherwise.
decompose_trade_costs <- function(cfg, gravity, hr_target, distances, asymmetries = NULL) {
  spec <- gravity$spec %||% gravity_spec(cfg)
  dom <- cfg$regions$domestic
  index_type <- cfg$trade_costs$measured_index %||% "symmetric"
  if (!index_type %in% c("symmetric", "augmented")) stopf("trade_costs$measured_index must be symmetric or augmented.")
  geo <- spec$geographic
  coefs <- gravity$coefficients |> filter(term %in% geo)
  estimated <- unique(gravity$coefficients$sector)
  dat <- pair_regressors(hr_target, distances, cfg) |>
    mutate(pair_type = case_when(origin %in% dom & dest %in% dom ~ "interprovincial",
                                 origin %in% dom | dest %in% dom ~ "international",
                                 TRUE ~ "foreign"))
  log_geo <- rep(0, nrow(dat))
  for (v in geo) {
    b <- coefs |> filter(term == v)
    bv <- b$estimate[match(dat$sector, b$sector)]
    log_geo <- log_geo + coalesce(bv, 0) * dat[[v]]
  }
  in_scope <- if (spec$sample == "all") rep(TRUE, nrow(dat)) else dat$pair_type == "interprovincial"
  dat$tau_geo <- ifelse(in_scope & dat$sector %in% estimated, exp(log_geo), NA_real_)
  # Geography should not make trade between two regions cheaper than trade
  # within them; without this floor, a negative distance or adjacency effect
  # would make "eliminating non-geographic costs" cut more than eliminating all
  # measured costs.
  geo_target <- if (!isFALSE(cfg$trade_costs$floor_geographic)) pmax(dat$tau_geo, 1) else dat$tau_geo

  if (is.null(asymmetries)) {
    dat$log_t_origin <- NA_real_
    dat$log_t_dest <- NA_real_
  } else {
    a <- asymmetries |> filter(year == cfg$years$target) |> select(region, sector, log_t)
    dat <- dat |>
      left_join(a |> rename(origin = region, log_t_origin = log_t), by = c("origin", "sector")) |>
      left_join(a |> rename(dest = region, log_t_dest = log_t), by = c("dest", "sector"))
  }
  dat |>
    mutate(
      tau_nongeo = tau_bar / tau_geo,
      tau_tilde = tau_bar * exp((log_t_origin - log_t_dest) / 2),
      tau_index = if (index_type == "augmented") coalesce(tau_tilde, tau_bar) else tau_bar,
      tau_hat_measured_10 = if_else(tau_index > 1, (1 + 0.9 * (tau_index - 1)) / tau_index, 1),
      tau_hat_nongeo = if_else(is.na(geo_target), 1, pmin(geo_target / tau_bar, 1)),
      tau_hat_asym = coalesce(pmin(1, exp(log_t_dest - log_t_origin)), 1),
      tau_hat_all = pmin(1 / tau_index, 1)
    ) |>
    select(year, origin, dest, sector, pair_type, theta, tau_bar, tau_tilde, tau_index,
           tau_geo, tau_nongeo, log_t_origin, log_t_dest, tau_hat_measured_10, tau_hat_nongeo,
           tau_hat_asym, tau_hat_all, distance_normalized, distance_km, adjacent)
}

#' Trade-weighted averages of measured trade costs (percent).
#'
#' @param costs Output of decompose_trade_costs().
#' @param flows Calibration-year flows (origin, dest, sector, value), used as weights.
#' @param by Grouping columns (e.g. "sector", "origin" or character(0)).
#' @return Tibble with, for interprovincial pairs:
#'   measured_cost             tau_bar - 1
#'   geography                 tau_geo - 1
#'   nongeography              tau_bar - tau_geo (additive split, as in Alvarez et al.)
#'   nondistance_contribution  tau_bar / tau_geo - 1 (Albrecht and Tombe, Table 4)
#'   nondistance_floor         max(tau_bar / tau_geo, 1) - 1 (non-negative)
#'   asymmetry_contribution    max(1, t[origin] / t[dest]) - 1
summarise_trade_costs <- function(costs, flows, by = character(0)) {
  costs |>
    filter(pair_type == "interprovincial") |>
    left_join(flows |> select(origin, dest, sector, w = value), by = c("origin", "dest", "sector")) |>
    mutate(w = coalesce(w, 0)) |>
    group_by(across(all_of(by))) |>
    summarise(
      pairs = n(),
      measured_cost = wmean(tau_bar - 1, w),
      geography = wmean(tau_geo - 1, w),
      nongeography = wmean(tau_bar - tau_geo, w),
      nondistance_contribution = wmean(tau_bar / tau_geo - 1, w),
      nondistance_floor = wmean(pmax(tau_bar / tau_geo, 1) - 1, w),
      asymmetry_contribution = wmean(pmax(exp(log_t_origin - log_t_dest), 1) - 1, w),
      .groups = "drop")
}

#' Weighted mean in percent over non-missing values.
wmean <- function(x, w) {
  ok <- !is.na(x) & !is.na(w)
  if (!any(ok) || sum(w[ok]) == 0) return(NA_real_)
  100 * sum(x[ok] * w[ok]) / sum(w[ok])
}
