"""Independent re-implementation of the IPT-Model equilibrium in changes.

Reads the cases written by tests/crosscheck/export_cases.R, solves each
counterfactual with SciPy's MINPACK hybrid root finder (a different algorithm
and a separate code base from the R solver) and compares wages, population,
price indexes and real incomes.

Usage (from the repository root):
    Rscript tests/crosscheck/export_cases.R [--real]
    python3 tests/crosscheck/solver_crosscheck.py
Requires numpy and scipy.
"""

import glob
import json
import sys

import numpy as np
from scipy.optimize import root


def load_case(path):
    with open(path) as f:
        raw = json.load(f)
    case = {}
    for key, value in raw.items():
        if isinstance(value, dict) and "dim" in value:
            case[key] = np.asarray(value["data"], dtype=float).reshape(value["dim"], order="F")
        else:
            case[key] = value
    for key in ("theta", "D", "VA", "I"):
        case[key] = np.asarray(case[key], dtype=float)
    case["population"] = np.array([np.nan if p is None else p for p in case["population"]], dtype=float)
    return case


def solve_prices(log_w, log_kappa, c, log_p0, tol=1e-14):
    """Fixed point for log price changes given log wage changes."""
    pi, phi, gamma, theta = c["pi"], c["phi"], c["gamma"], c["theta"]
    with np.errstate(divide="ignore"):
        log_pi = np.log(pi)
    log_p = log_p0.copy()
    for _ in range(20000):
        # log c[i, j] = phi log w + (1 - phi) sum_k gamma[i, k, j] log p[i, k]
        log_c = phi * log_w[:, None] + (1 - phi) * np.einsum("ik,ikj->ij", log_p, gamma)
        # m[n, i, j] = log pi - theta_j (log kappa + log c[i, j])
        m = log_pi - theta[None, None, :] * (log_kappa + log_c[None, :, :])
        mx = np.max(m, axis=1, keepdims=True)
        lse = mx[:, 0, :] + np.log(np.sum(np.exp(m - mx), axis=1))
        new = -lse / theta[None, :]
        if np.max(np.abs(new - log_p)) < tol:
            log_p = new
            break
        log_p = new
    log_c = phi * log_w[:, None] + (1 - phi) * np.einsum("ik,ikj->ij", log_p, gamma)
    return log_p, log_c


def evaluate(x, c, state):
    N, J = c["phi"].shape
    mobile = np.array([r in c["mobile"] for r in c["regions"]])
    log_w = x[:N]
    log_L = np.zeros(N)
    log_L[mobile] = x[N:]
    log_kappa = np.log(c["tau_hat"]) + np.log1p(c["tariff_new"]) - np.log1p(c["tariff"])
    log_p, log_c = solve_prices(log_w, log_kappa, c, state["log_p"])
    state["log_p"] = log_p
    theta = c["theta"]
    pi_new = c["pi"] * np.exp(-theta[None, None, :] * (log_kappa + log_c[None, :, :])
                              + theta[None, None, :] * log_p[:, None, :])
    t = c["tariff_new"]
    a = pi_new / (1 + t)                       # [n, i, j] revenue received by i
    tr = np.sum(pi_new * t / (1 + t), axis=1)  # [n, j] tariff revenue share
    phi, gamma, beta = c["phi"], c["gamma"], c["beta"]
    va_supply = np.exp(log_w + log_L) * c["VA"]
    E = va_supply + c["D"]
    # Unknown X[n, j]; equations:
    # X[n, j] - sum_k gamma[n, j, k] (1 - phi[n, k]) sum_m a[m, n, k] X[m, k]
    #         - beta[n, j] sum_k tr[n, k] X[n, k] = beta[n, j] E[n]
    NJ = N * J
    A = np.eye(NJ)
    def ix(n, j):
        return j * N + n
    for n in range(N):
        for j in range(J):
            r = ix(n, j)
            for k in range(J):
                coef = gamma[n, j, k] * (1 - phi[n, k])
                for m in range(N):
                    A[r, ix(m, k)] -= coef * a[m, n, k]
                A[r, ix(n, k)] -= beta[n, j] * tr[n, k]
    b = np.zeros(NJ)
    for n in range(N):
        for j in range(J):
            b[ix(n, j)] = beta[n, j] * E[n]
    X = np.linalg.solve(A, b).reshape((J, N)).T          # X[n, j]
    R = np.einsum("mnk,mk->nk", a, X)                     # R[n, k]
    I_new = E + np.sum(tr * X, axis=1)
    va_demand = np.sum(phi * R, axis=1)
    f = (va_demand - va_supply) / c["VA"]
    f[-1] = va_supply.sum() / c["VA"].sum() - 1
    log_P = np.sum(beta * log_p, axis=1)
    if mobile.any():
        pop = c["population"][mobile]
        share = pop / pop.sum()
        log_U = np.log(I_new / c["I"]) - log_L - log_P
        a_m = c["kappa"] * log_U[mobile]
        g = log_L[mobile] - (a_m - np.log(np.sum(share * np.exp(a_m))))
        f = np.concatenate([f, g])
    return f, {"w_hat": np.exp(log_w), "L_hat": np.exp(log_L), "P_hat": np.exp(log_P),
               "real_income": (I_new / c["I"]) / np.exp(log_P)}


def check(path, tol=1e-6):
    c = load_case(path)
    N, J = c["phi"].shape
    n_mob = sum(r in c["mobile"] for r in c["regions"])
    state = {"log_p": np.zeros((N, J))}
    sol = root(lambda x: evaluate(x, c, state)[0], np.zeros(N + n_mob), method="hybr",
               options={"xtol": 1e-13})
    f, out = evaluate(sol.x, c, state)
    ok = sol.success and np.max(np.abs(f)) < 1e-9
    worst = 0.0
    for key in ("w_hat", "L_hat", "P_hat", "real_income"):
        diff = np.max(np.abs(out[key] - np.asarray(c["solution"][key], dtype=float)))
        worst = max(worst, diff)
        print(f"  {key:12s} max |python - R| = {diff:.2e}")
    status = "OK" if ok and worst < tol else "MISMATCH"
    print(f"{path}: {status} (residual {np.max(np.abs(f)):.1e})")
    return status == "OK"


if __name__ == "__main__":
    files = sorted(glob.glob("tests/crosscheck/cases/*.json"))
    if not files:
        sys.exit("No cases found; run tests/crosscheck/export_cases.R first.")
    results = [check(f) for f in files]
    sys.exit(0 if all(results) else 1)
