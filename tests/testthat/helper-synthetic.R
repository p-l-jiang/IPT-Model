# Synthetic economies for unit tests.

#' Random economy with N regions and J sectors.
#'
#' @param deficits Use the trade imbalances implied by the random flows (TRUE)
#'   or balanced trade (FALSE).
#' @param io Intermediate inputs (FALSE sets phi = 1 and gamma irrelevant).
make_synthetic_base <- function(N = 4, J = 3, seed = 1, deficits = TRUE, io = TRUE,
                                theta = NULL, home_bias = 5) {
  set.seed(seed)
  regions <- paste0("R", seq_len(N))
  sectors <- paste0("S", seq_len(J))
  dn3 <- list(dest = regions, origin = regions, sector = sectors)
  flows <- array(stats::runif(N * N * J, 0.5, 2), c(N, N, J), dimnames = dn3)
  for (j in seq_len(J)) diag(flows[, , j]) <- diag(flows[, , j]) * home_bias
  phi <- if (io) matrix(stats::runif(N * J, 0.3, 0.7), N, J) else matrix(1, N, J)
  dimnames(phi) <- list(regions, sectors)
  gamma <- array(stats::runif(N * J * J), c(N, J, J),
                 dimnames = list(regions, input = sectors, user = sectors))
  gamma <- sweep(gamma, c(1, 3), apply(gamma, c(1, 3), sum), "/")
  beta <- matrix(stats::runif(N * J), N, J, dimnames = list(regions, sectors))
  beta <- beta / rowSums(beta)
  base <- list(
    regions = regions, sectors = sectors, domestic = regions[-N],
    pi = shares_from_flows(flows), phi = phi, gamma = gamma, beta = beta,
    theta = theta %||% setNames(stats::runif(J, 3, 8), sectors),
    tariff = array(0, c(N, N, J), dimnames = dn3),
    population = setNames(c(stats::runif(N - 1, 1, 10), NA), regions),
    va_data = setNames(stats::runif(N, 1, 2), regions)
  )
  D <- setNames(rep(0, N), regions)
  if (deficits) {
    D <- deficits_from_flows(flows)
    D <- D - mean(D)
    D <- D / sum(abs(D)) * 0.2 * sum(base$va_data)  # imbalances of about 10% of income
  }
  lv <- solve_baseline_levels(base, D, sum(base$va_data))
  c(base, list(D = D, X = lv$X, R = lv$R, VA = lv$VA, I = lv$I))
}

#' Random iceberg shock array with values in [lo, hi] off the diagonal.
random_tau_hat <- function(base, lo = 0.8, hi = 1.2, seed = 2) {
  set.seed(seed)
  N <- length(base$regions)
  J <- length(base$sectors)
  t <- array(stats::runif(N * N * J, lo, hi), dim(base$pi), dimnames(base$pi))
  for (j in seq_len(J)) diag(t[, , j]) <- 1
  t
}
