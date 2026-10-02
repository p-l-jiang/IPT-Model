# Equilibrium of the multi-sector Eaton-Kortum model with input-output
# linkages (Caliendo and Parro, 2015), in levels (baseline) and in changes
# ("exact hat algebra", Dekle, Eaton and Kortum, 2008).
#
# Notation (see docs/model.md):
#   n = destination, i = origin, j/k = sectors; N regions, J sectors.
#   pi[n, i, j]     share of n's spending on sector j that goes to origin i
#   phi[n, j]       value-added share of gross output
#   gamma[n, k, j]  share of input k in sector j's intermediate-input bill
#   beta[n, j]      final-demand share
#   theta[j]        trade elasticity
#   t[n, i, j]      ad valorem tariff charged by n on imports from i
#   D[n]            trade deficit (held fixed in units of world value added)
#
# Equilibrium in changes (x_hat = x' / x):
#   c_hat[i, j]  = w_hat[i]^phi[i, j] * prod_k p_hat[i, k]^((1 - phi[i, j]) gamma[i, k, j])
#   p_hat[n, j]  = (sum_i pi[n, i, j] (kappa_hat[n, i, j] c_hat[i, j])^-theta[j])^(-1 / theta[j])
#   pi'[n, i, j] = pi[n, i, j] (kappa_hat[n, i, j] c_hat[i, j] / p_hat[n, j])^-theta[j]
#   X'[n, j]     = sum_k gamma[n, j, k] (1 - phi[n, k]) R'[n, k] + beta[n, j] I'[n]
#   R'[i, j]     = sum_n pi'[n, i, j] X'[n, j] / (1 + t'[n, i, j])
#   I'[n]        = VA'[n] + D[n] + sum_{i, j} t'[n, i, j] pi'[n, i, j] X'[n, j] / (1 + t'[n, i, j])
#   VA'[n]       = w_hat[n] L_hat[n] VA[n] = sum_j phi[n, j] R'[n, j]
#   sum_n VA'[n] = sum_n VA[n]                         (numeraire: world value added)
# where kappa_hat = tau_hat * (1 + t') / (1 + t) combines iceberg-cost and tariff
# changes. With labour mobility across the regions in `mobile` (Fréchet
# location preferences with elasticity kappa),
#   L_hat[n] = U_hat[n]^kappa / sum_m l[m] U_hat[m]^kappa,
#   U_hat[n] = (I'[n] / I[n]) / (L_hat[n] P_hat[n]),  P_hat[n] = prod_j p_hat[n, j]^beta[n, j],
# where l[m] are baseline population shares within the mobile set.

# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

#' Log unit-cost changes, log c_hat [N x J].
log_unit_cost <- function(log_w, log_p, phi, gamma) {
  N <- nrow(phi)
  out <- phi * log_w  # recycles log_w down columns (one value per region)
  for (i in seq_len(N)) {
    out[i, ] <- out[i, ] + (1 - phi[i, ]) * as.vector(log_p[i, ] %*% gamma[i, , ])
  }
  out
}

#' Row-wise log-sum-exp of a matrix whose -Inf entries represent zeros.
row_log_sum_exp <- function(m) {
  mx <- apply(m, 1, max)
  mx[!is.finite(mx)] <- 0
  mx + log(rowSums(exp(m - mx)))
}

#' Solve the price block for given wage changes.
#'
#' Iterates the contraction p_hat = F(p_hat; w_hat) in logs.
#' @return List: log_p [N x J], log_c [N x J], iterations.
solve_prices <- function(log_w, log_kappa, base, log_p_init = NULL, tol = 1e-13, max_iter = 5000) {
  N <- length(base$regions)
  J <- length(base$sectors)
  log_pi <- log(base$pi)
  theta <- base$theta
  log_p <- log_p_init %||% matrix(0, N, J, dimnames = list(base$regions, base$sectors))
  for (it in seq_len(max_iter)) {
    log_c <- log_unit_cost(log_w, log_p, base$phi, base$gamma)
    log_p_new <- log_p
    for (j in seq_len(J)) {
      m <- log_pi[, , j] - theta[j] * (log_kappa[, , j] + matrix(log_c[, j], N, N, byrow = TRUE))
      log_p_new[, j] <- -row_log_sum_exp(m) / theta[j]
    }
    if (max(abs(log_p_new - log_p)) < tol) {
      log_p <- log_p_new
      return(list(log_p = log_p, log_c = log_unit_cost(log_w, log_p, base$phi, base$gamma),
                  iterations = it))
    }
    log_p <- log_p_new
  }
  stopf("Price block did not converge in %d iterations.", max_iter)
}

#' Counterfactual trade shares pi' [N x N x J].
new_trade_shares <- function(log_kappa, log_c, log_p, base) {
  N <- length(base$regions)
  J <- length(base$sectors)
  out <- base$pi
  for (j in seq_len(J)) {
    th <- base$theta[j]
    e <- -th * (log_kappa[, , j] + matrix(log_c[, j], N, N, byrow = TRUE)) +
      th * matrix(log_p[, j], N, N)
    out[, , j] <- base$pi[, , j] * exp(e)
  }
  out
}

#' Linear expenditure system for given trade shares and tariffs.
#'
#' Expenditure X (vectorised column-major as x[n + (j - 1) N]) solves
#'   x = G A x + B (E + Tr x),
#' where A maps expenditure to producer revenue, G intermediate demand, B
#' final-demand shares and Tr tariff revenue; E is income other than tariff
#' revenue (value added plus deficit). Returns the operators needed to map E
#' into expenditure, revenue, value added and tariff revenue.
expenditure_operators <- function(pi, tariff, base) {
  N <- length(base$regions)
  J <- length(base$sectors)
  NJ <- N * J

  # a[m, n, k]: share of m's spending on k received (net of tariffs) by n.
  a <- pi / (1 + tariff)
  # tr[n, k]: share of n's spending on k collected as tariff revenue.
  tr <- apply(pi * tariff / (1 + tariff), c(1, 3), sum)
  # g[n, j, k] = gamma[n, j, k] (1 - phi[n, k]): input j per unit of k's revenue.
  g <- base$gamma * aperm(array(1 - base$phi, c(N, J, J)), c(1, 3, 2))

  # Intermediate demand for (n, j) generated by spending of (m, k):
  #   GA[(n, j), (m, k)] = g[n, j, k] * a[m, n, k],
  # with rows/columns ordered (region fastest, then sector).
  g4 <- array(g, c(N, J, J, N))                          # [n, j, k, m]
  a4 <- aperm(array(a, c(N, N, J, J)), c(2, 4, 3, 1))    # [n, j, k, m]
  GA <- matrix(aperm(g4 * a4, c(1, 2, 4, 3)), NJ, NJ)

  B <- matrix(0, NJ, N)                                  # final-demand shares
  for (n in seq_len(N)) B[n + (seq_len(J) - 1) * N, n] <- base$beta[n, ]
  lhs <- diag(NJ) - GA
  if (any(tr != 0)) {
    for (n in seq_len(N)) {
      rows <- n + (seq_len(J) - 1) * N
      lhs[rows, rows] <- lhs[rows, rows] - outer(base$beta[n, ], tr[n, ])
    }
  }
  H <- solve(lhs, B)                                     # x = H E

  # Value added generated by one unit of each region's income: M = Phi A H.
  M <- matrix(0, N, N)
  for (k in seq_len(J)) {
    rows <- seq_len(N) + (k - 1) * N
    M <- M + base$phi[, k] * (t(a[, , k]) %*% H[rows, , drop = FALSE])
  }
  list(H = H, a = a, tr = tr, M = M, N = N, J = J)
}

#' Value added consistent with given trade shares, deficits and numeraire.
#'
#' Solves VA = M (VA + D) subject to sum(VA) = va_total.
solve_value_added <- function(ops, D, va_total) {
  N <- ops$N
  lhs <- diag(N) - ops$M
  rhs <- as.vector(ops$M %*% D)
  lhs[N, ] <- 1
  rhs[N] <- va_total
  as.vector(solve(lhs, rhs))
}

#' Expenditure, revenue and income implied by value added.
levels_from_value_added <- function(ops, VA, D, base) {
  E <- VA + D
  dn <- list(base$regions, base$sectors)
  X <- matrix(as.vector(ops$H %*% E), ops$N, ops$J, dimnames = dn)
  R <- X
  for (k in seq_len(ops$J)) R[, k] <- as.vector(t(ops$a[, , k]) %*% X[, k])
  tariff_revenue <- rowSums(ops$tr * X)
  list(X = X, R = R, VA = setNames(VA, base$regions),
       tariff_revenue = setNames(tariff_revenue, base$regions),
       I = setNames(E + tariff_revenue, base$regions))
}

# ---------------------------------------------------------------------------
# Baseline equilibrium in levels
# ---------------------------------------------------------------------------

#' Solve for baseline levels given trade shares and deficits.
#'
#' Given pi, phi, gamma, beta, the deficits D and baseline tariffs, there is a
#' unique (up to scale) set of expenditures, revenues and value added that
#' satisfies the market-clearing conditions; `va_total` fixes the scale.
solve_baseline_levels <- function(base, D, va_total) {
  ops <- expenditure_operators(base$pi, base$tariff, base)
  VA <- solve_value_added(ops, D, va_total)
  levels_from_value_added(ops, VA, D, base)
}

# ---------------------------------------------------------------------------
# Counterfactual equilibrium in changes
# ---------------------------------------------------------------------------

#' Solve for the counterfactual equilibrium.
#'
#' @param base Baseline (see build_baseline()).
#' @param tau_hat Iceberg trade-cost changes [N x N x J] (default: no change).
#' @param tariff_new Counterfactual ad valorem tariffs [N x N x J] (default:
#'   baseline tariffs).
#' @param D_new Counterfactual deficits (default: baseline deficits).
#' @param migration_elasticity Elasticity of population to real income per
#'   capita across the regions in `mobile` (0 = no migration).
#' @param mobile Regions between which labour is mobile.
#' @param control List of numerical settings (tolerance, max_iter, damping).
#' @return List with hat changes and counterfactual levels; see results.R.
solve_counterfactual <- function(base, tau_hat = NULL, tariff_new = NULL, D_new = NULL,
                                 migration_elasticity = 0, mobile = character(0),
                                 control = list()) {
  tol <- control$tolerance %||% 1e-10
  max_iter <- control$max_iter %||% 100
  N <- length(base$regions)
  dn3 <- dimnames(base$pi)

  tau_hat <- tau_hat %||% array(1, dim(base$pi), dn3)
  tariff_new <- tariff_new %||% base$tariff
  D_new <- D_new %||% base$D
  if (any(tau_hat <= 0)) stopf("tau_hat must be strictly positive.")
  if (any(tariff_new <= -1)) stopf("Tariffs must be greater than -100%%.")
  if (abs(sum(D_new)) > 1e-8 * sum(base$VA)) stopf("Counterfactual deficits must sum to zero.")
  log_kappa <- log(tau_hat) + log1p(tariff_new) - log1p(base$tariff)

  mob <- base$regions %in% mobile & migration_elasticity > 0
  pop_share <- base$population[mob] / sum(base$population[mob])
  if (migration_elasticity > 0 && (!any(mob) || anyNA(pop_share))) {
    stopf("Migration needs baseline population for the mobile regions.")
  }

  # Equilibrium system F(x) = 0 in x = (log w_hat, log L_hat[mobile]):
  #   relative excess demand for labour in every region but the last (the
  #   last is implied by Walras' law), the numeraire, and the migration
  #   conditions. Prices are warm-started from the previous evaluation.
  state <- new.env()
  state$log_p <- NULL
  evaluate <- function(x) {
    log_w <- setNames(x[seq_len(N)], base$regions)
    log_L <- setNames(rep(0, N), base$regions)
    log_L[mob] <- x[N + seq_len(sum(mob))]
    prices <- solve_prices(log_w, log_kappa, base, state$log_p)
    state$log_p <- prices$log_p
    pi_new <- new_trade_shares(log_kappa, prices$log_c, prices$log_p, base)
    ops <- expenditure_operators(pi_new, tariff_new, base)
    va_supply <- exp(log_w + log_L) * base$VA
    lv <- levels_from_value_added(ops, va_supply, D_new, base)
    va_demand <- rowSums(base$phi * lv$R)
    f <- (va_demand - va_supply) / base$VA
    f[N] <- sum(va_supply) / sum(base$VA) - 1
    if (any(mob)) {
      log_U <- log(lv$I / base$I) - log_L - rowSums(base$beta * prices$log_p)
      a <- migration_elasticity * log_U[mob]
      f <- c(f, log_L[mob] - (a - log(sum(pop_share * exp(a)))))
    }
    list(f = f, prices = prices, pi = pi_new, levels = lv, log_w = log_w, log_L = log_L,
         va_demand = va_demand)
  }

  x <- rep(0, N + sum(mob))
  cur <- evaluate(x)
  history <- max(abs(cur$f))
  converged <- history < tol
  iter <- 0
  h <- 1e-6
  while (!converged && iter < max_iter) {
    iter <- iter + 1
    # Finite-difference Jacobian.
    Jm <- matrix(0, length(x), length(x))
    for (k in seq_along(x)) {
      xk <- x
      xk[k] <- xk[k] + h
      Jm[, k] <- (evaluate(xk)$f - cur$f) / h
    }
    step <- tryCatch(solve(Jm, -cur$f), error = function(e) NULL)
    if (is.null(step)) stopf("Singular Jacobian in the equilibrium solver.")
    # Backtracking line search on the sup norm of the residuals.
    t <- 1
    repeat {
      cand <- tryCatch(evaluate(x + t * step), error = function(e) NULL)
      if (!is.null(cand) && all(is.finite(cand$f)) &&
          max(abs(cand$f)) < (1 - 1e-4 * t) * max(abs(cur$f))) break
      t <- t / 2
      if (t < 1e-6) stopf("Line search failed in the equilibrium solver (residual %.2e).",
                          max(abs(cur$f)))
    }
    x <- x + t * step
    cur <- cand
    history <- c(history, max(abs(cur$f)))
    converged <- max(abs(cur$f)) < tol
  }
  if (!converged) warnf("Counterfactual did not converge in %d Newton steps (residual %.2e).",
                        max_iter, utils::tail(history, 1))

  prices <- cur$prices
  lv <- cur$levels
  list(
    w_hat = exp(cur$log_w), L_hat = exp(cur$log_L),
    p_hat = exp(prices$log_p), c_hat = exp(prices$log_c),
    P_hat = exp(rowSums(base$beta * prices$log_p)),
    pi = cur$pi, X = lv$X, R = lv$R, VA = setNames(cur$va_demand, base$regions), I = lv$I,
    tariff_revenue = lv$tariff_revenue, D = D_new, tariff = tariff_new,
    converged = converged, iterations = iter, history = history
  )
}

#' Residuals of the equilibrium conditions (for testing and diagnostics).
equilibrium_residuals <- function(sol, base) {
  dn <- list(base$regions, base$sectors)
  N <- length(base$regions)
  J <- length(base$sectors)
  # Market clearing for goods: R = sum_n pi' X / (1 + t')
  R_implied <- matrix(0, N, J, dimnames = dn)
  X_implied <- matrix(0, N, J, dimnames = dn)
  for (j in seq_len(J)) R_implied[, j] <- colSums(sol$pi[, , j] * sol$X[, j] / (1 + sol$tariff[, , j]))
  tr <- sapply(seq_len(J), function(j) rowSums(sol$pi[, , j] * sol$tariff[, , j] / (1 + sol$tariff[, , j])))
  for (n in seq_len(N)) {
    X_implied[n, ] <- as.vector(base$gamma[n, , ] %*% ((1 - base$phi[n, ]) * sol$R[n, ])) +
      base$beta[n, ] * (sol$VA[n] + sol$D[n] + sum(tr[n, ] * sol$X[n, ]))
  }
  list(
    goods = max(abs(R_implied - sol$R)) / max(sol$R),
    expenditure = max(abs(X_implied - sol$X)) / max(sol$X),
    labour = max(abs(rowSums(base$phi * sol$R) - sol$w_hat * sol$L_hat * base$VA)) / max(base$VA),
    shares = max(abs(apply(sol$pi, c(1, 3), sum) - 1))
  )
}
