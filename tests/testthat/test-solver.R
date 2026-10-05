test_that("baseline levels satisfy the equilibrium conditions", {
  base <- make_synthetic_base()
  sol <- list(pi = base$pi, X = base$X, R = base$R, VA = base$VA, D = base$D,
              tariff = base$tariff, w_hat = setNames(rep(1, 4), base$regions),
              L_hat = setNames(rep(1, 4), base$regions))
  res <- equilibrium_residuals(sol, base)
  expect_lt(max(unlist(res)), 1e-10)
  expect_equal(sum(base$VA), sum(base$va_data))
  expect_equal(unname(base$I), unname(base$VA + base$D))
})

test_that("a shock-free counterfactual returns the baseline (identity)", {
  base <- make_synthetic_base()
  sol <- solve_counterfactual(base)
  expect_true(sol$converged)
  expect_equal(unname(sol$w_hat), rep(1, 4), tolerance = 1e-10)
  expect_equal(as.vector(sol$p_hat), rep(1, 12), tolerance = 1e-10)
  expect_equal(sol$pi, base$pi, tolerance = 1e-10)

  mig <- solve_counterfactual(base, migration_elasticity = 1.5, mobile = base$domestic)
  expect_equal(unname(mig$L_hat), rep(1, 4), tolerance = 1e-10)
})

test_that("counterfactual solutions satisfy market clearing and the numeraire", {
  base <- make_synthetic_base(N = 5, J = 4, seed = 3)
  sol <- solve_counterfactual(base, tau_hat = random_tau_hat(base, 0.7, 1.4))
  expect_true(sol$converged)
  expect_lt(max(unlist(equilibrium_residuals(sol, base))), 1e-8)
  expect_equal(sum(sol$w_hat * sol$L_hat * base$VA), sum(base$VA), tolerance = 1e-10)
  expect_equal(unname(sol$I), unname(sol$VA + base$D), tolerance = 1e-8)
})

test_that("one-sector model without intermediates matches the ACR welfare formula", {
  # With phi = 1, J = 1 and balanced trade, real income changes by
  # pi_hat[n, n]^(-1 / theta) (Arkolakis, Costinot and Rodriguez-Clare, 2012).
  base <- make_synthetic_base(N = 4, J = 1, seed = 4, deficits = FALSE, io = FALSE,
                              theta = c(S1 = 4))
  sol <- solve_counterfactual(base, tau_hat = random_tau_hat(base, 0.6, 1.5, seed = 5))
  pi_hat_own <- diag(sol$pi[, , 1]) / diag(base$pi[, , 1])
  welfare <- (sol$I / base$I) / sol$P_hat
  expect_equal(unname(welfare), unname(pi_hat_own^(-1 / 4)), tolerance = 1e-8)
})

test_that("one-sector roundabout model matches pi_hat^(-1 / (theta phi))", {
  base <- make_synthetic_base(N = 3, J = 1, seed = 6, deficits = FALSE, theta = c(S1 = 5))
  base$phi[] <- 0.4
  lv <- solve_baseline_levels(base, base$D, sum(base$va_data))
  base[c("X", "R", "VA", "I")] <- lv[c("X", "R", "VA", "I")]
  sol <- solve_counterfactual(base, tau_hat = random_tau_hat(base, 0.7, 1.3, seed = 7))
  pi_hat_own <- diag(sol$pi[, , 1]) / diag(base$pi[, , 1])
  welfare <- (sol$I / base$I) / sol$P_hat
  expect_equal(unname(welfare), unname(pi_hat_own^(-1 / (5 * 0.4))), tolerance = 1e-8)
})

test_that("ad valorem tariffs raise revenue that is rebated to the importer", {
  base <- make_synthetic_base(N = 3, J = 2, seed = 8)
  tariff <- base$tariff
  tariff["R1", c("R2", "R3"), ] <- 0.25
  sol <- solve_counterfactual(base, tariff_new = tariff)
  expect_true(sol$converged)
  expect_lt(max(unlist(equilibrium_residuals(sol, base))), 1e-8)
  revenue <- sum(sapply(1:2, function(j) sum(sol$pi["R1", , j] * tariff["R1", , j] /
                                                (1 + tariff["R1", , j])) * sol$X["R1", j]))
  expect_equal(unname(sol$tariff_revenue["R1"]), revenue, tolerance = 1e-10)
  expect_equal(unname(sol$tariff_revenue[c("R2", "R3")]), c(0, 0))
  expect_equal(unname(sol$I), unname(sol$VA + base$D + sol$tariff_revenue), tolerance = 1e-8)
  # An iceberg cost of the same size wastes the revenue: the importer is worse off.
  ice <- array(1, dim(base$pi), dimnames(base$pi))
  ice["R1", c("R2", "R3"), ] <- 1.25
  sol_ice <- solve_counterfactual(base, tau_hat = ice)
  welfare <- function(s) unname((s$I["R1"] / base$I["R1"]) / s$P_hat["R1"])
  expect_gt(welfare(sol), welfare(sol_ice))
})

test_that("migration conserves the mobile population and leaves others fixed", {
  base <- make_synthetic_base(N = 4, J = 3, seed = 9)
  sol <- solve_counterfactual(base, tau_hat = random_tau_hat(base, 0.8, 1.2, seed = 10),
                              migration_elasticity = 1.5, mobile = base$domestic)
  expect_true(sol$converged)
  mob <- base$domestic
  share <- base$population[mob] / sum(base$population[mob])
  expect_equal(sum(share * sol$L_hat[mob]), 1, tolerance = 1e-10)
  expect_equal(unname(sol$L_hat["R4"]), 1)
  # Population moves towards regions with higher real income per capita.
  U <- (sol$I / base$I) / (sol$L_hat * sol$P_hat)
  expect_equal(order(sol$L_hat[mob]), order(U[mob]))
  expect_lt(max(unlist(equilibrium_residuals(sol, base))), 1e-8)
})

test_that("purging deficits produces a balanced-trade equilibrium", {
  base <- make_synthetic_base(N = 3, J = 2, seed = 11)
  sol <- solve_counterfactual(base, D_new = setNames(rep(0, 3), base$regions))
  expect_true(sol$converged)
  expect_equal(unname(sol$I), unname(sol$VA), tolerance = 1e-8)
  expect_lt(max(unlist(equilibrium_residuals(sol, base))), 1e-8)
})

test_that("the solver is robust to very high trade elasticities and large shocks", {
  base <- make_synthetic_base(N = 4, J = 2, seed = 12, theta = c(S1 = 70, S2 = 3))
  ice <- array(1, dim(base$pi), dimnames(base$pi))
  ice["R1", -1, ] <- 1.5
  ice[-1, "R1", ] <- 0.9
  sol <- solve_counterfactual(base, tau_hat = ice)
  expect_true(sol$converged)
  expect_lt(max(unlist(equilibrium_residuals(sol, base))), 1e-8)
})

test_that("autarky reproduces the gains from trade of the ACR formula", {
  # With J = 1, phi = 1 and balanced trade, welfare in autarky relative to the
  # observed equilibrium is pi[n, n]^(1 / theta).
  base <- make_synthetic_base(N = 4, J = 1, seed = 6, deficits = FALSE, io = FALSE, theta = c(S1 = 5))
  tau_hat <- array(Inf, dim(base$pi), dimnames(base$pi))
  diag(tau_hat[, , 1]) <- 1
  sol <- solve_counterfactual(base, tau_hat = tau_hat)
  expect_equal(unname((sol$I / base$I) / sol$P_hat), unname(diag(base$pi[, , 1])^(1 / 5)), tolerance = 1e-8)
  expect_equal(unname(diag(sol$pi[, , 1])), rep(1, 4))
  # Roundabout production: pi[n, n]^(1 / (theta phi)).
  base <- make_synthetic_base(N = 3, J = 1, seed = 7, deficits = FALSE, io = TRUE, theta = c(S1 = 4))
  tau_hat <- array(Inf, dim(base$pi), dimnames(base$pi))
  diag(tau_hat[, , 1]) <- 1
  sol <- solve_counterfactual(base, tau_hat = tau_hat)
  expect_equal(unname((sol$I / base$I) / sol$P_hat),
               unname(diag(base$pi[, , 1])^(1 / (4 * base$phi[, 1]))), tolerance = 1e-8)
})
