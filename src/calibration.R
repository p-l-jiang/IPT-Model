# Baseline calibration.
#
# The baseline must itself be an equilibrium of the model, otherwise a
# counterfactual with no shock (tau_hat = 1) does not return "no change" and
# every reported effect mixes the policy with a re-balancing of inconsistent
# data. The legacy code took trade shares, final-demand shares, IO
# coefficients and incomes from different sources and imposed balanced trade,
# so its baseline was not an equilibrium. Here:
#   * trade shares pi, IO parameters (phi, gamma) and final-demand shares beta
#     are taken from the data;
#   * observed trade imbalances D are held fixed (Caliendo and Parro, 2015),
#     or optionally purged by solving the model with D = 0 first;
#   * expenditures, revenues and value added are then solved from the model's
#     market-clearing conditions, with world value added equal to the data.
# Differences between model-implied and observed value added are reported as
# diagnostics.

#' Convert a long flow table into an array [dest, origin, sector].
flow_array <- function(flows, regions, sectors) {
  arr <- array(0, c(length(regions), length(regions), length(sectors)),
               dimnames = list(dest = regions, origin = regions, sector = sectors))
  f <- flows |> filter(origin %in% regions, dest %in% regions, sector %in% sectors)
  arr[cbind(match(f$dest, regions), match(f$origin, regions), match(f$sector, sectors))] <- f$value
  arr
}

#' Expenditure shares from a flow array. Destinations with no recorded
#' spending on a sector are assigned a home share of one.
shares_from_flows <- function(flows_arr) {
  N <- dim(flows_arr)[1]
  J <- dim(flows_arr)[3]
  pi <- flows_arr
  for (j in seq_len(J)) {
    tot <- rowSums(flows_arr[, , j])
    for (n in seq_len(N)) {
      if (tot[n] > 0) {
        pi[n, , j] <- flows_arr[n, , j] / tot[n]
      } else {
        pi[n, , j] <- 0
        pi[n, n, j] <- 1
      }
    }
  }
  pi
}

#' Trade deficit by region implied by a flow array (imports minus exports,
#' including flows with all other regions).
deficits_from_flows <- function(flows_arr) {
  absorption <- apply(flows_arr, 1, sum)
  output <- apply(flows_arr, 2, sum)
  absorption - output
}

#' Baseline population by region (persons). Foreign regions get NA.
baseline_population <- function(cfg, year) {
  pop <- read_population(cfg)
  to_region <- statcan_name_to_region()
  p <- pop |>
    filter(year == !!year) |>
    mutate(region = unname(to_region[geo])) |>
    filter(region %in% cfg$regions$domestic)
  if (nrow(p) == 0) stopf("No population data for %d.", year)
  out <- setNames(rep(NA_real_, length(model_regions(cfg))), model_regions(cfg))
  out[p$region] <- p$population
  out
}

#' Build the calibrated baseline.
#'
#' @param flows Long flow table for the calibration year (year, origin, dest, sector, value).
#' @param io Output of build_io_parameters().
#' @param theta Named trade elasticities.
#' @param population Named population vector (domestic regions).
#' @param va_data Named observed value added by region (CAD millions).
build_baseline <- function(cfg, flows, io, theta, population, va_data) {
  regions <- model_regions(cfg)
  sectors <- model_sectors(cfg)
  N <- length(regions)
  flows_arr <- flow_array(flows, regions, sectors)
  missing_regions <- regions[apply(flows_arr, 1, sum) == 0 | apply(flows_arr, 2, sum) == 0]
  if (length(missing_regions) > 0) stopf("No trade-flow data for region(s): %s",
                                         paste(missing_regions, collapse = ", "))
  base <- list(
    regions = regions, sectors = sectors, domestic = cfg$regions$domestic,
    year = cfg$years$target,
    pi = shares_from_flows(flows_arr),
    phi = io$phi[regions, sectors],
    gamma = io$gamma[regions, sectors, sectors],
    beta = io$beta[regions, sectors],
    theta = theta[sectors],
    tariff = array(0, dim(flows_arr), dimnames(flows_arr)),
    population = population[regions],
    flows_data = flows_arr,
    va_data = va_data[regions]
  )
  D <- deficits_from_flows(flows_arr)
  D <- D - mean(D)  # remove floating-point residue so that sum(D) = 0 exactly
  lv <- solve_baseline_levels(base, D, sum(base$va_data))
  base <- c(base, list(D = D, X = lv$X, R = lv$R, VA = lv$VA, I = lv$I))

  if (cfg$calibration$deficits == "purge") {
    log_info("Purging trade imbalances (solving the model with D = 0) ...")
    sol <- solve_counterfactual(base, D_new = setNames(rep(0, N), regions),
                                control = cfg$solver)
    if (!sol$converged) stopf("Could not purge deficits: solver did not converge.")
    base$pi <- sol$pi
    base$D <- sol$D
    base$X <- sol$X
    base$R <- sol$R
    base$VA <- sol$VA
    base$I <- sol$I
  }
  base$diagnostics <- baseline_diagnostics(base)
  base
}

#' Compare model-implied baseline levels with the data.
baseline_diagnostics <- function(base) {
  flows_arr <- base$flows_data
  tibble(
    region = base$regions,
    va_data = base$va_data,
    va_model = base$VA,
    va_gap_pct = 100 * (base$VA / base$va_data - 1),
    output_data = apply(flows_arr, 2, sum),
    output_model = rowSums(base$R),
    absorption_data = apply(flows_arr, 1, sum),
    absorption_model = rowSums(base$X),
    deficit = base$D,
    deficit_pct_va = 100 * base$D / base$VA,
    income = base$I
  )
}
