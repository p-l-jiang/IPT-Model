# Reporting of counterfactual outcomes.
#
# Welfare. With Cobb-Douglas final demand, the change in real income of region
# n is (I'[n] / I[n]) / P_hat[n], where income I includes value added, the
# (fixed) trade deficit and tariff revenue. Per-capita real income divides by
# the population change L_hat[n]. All nominal values are relative to world value
# added (the numeraire), so nominal changes are not informative on their own.
#
# Sectoral outcomes. Gross output (and value added, since value-added shares are
# fixed) of sector j in region n changes by R_hat[n, j]; employment in the
# sector changes by R_hat[n, j] / w_hat[n]. (The legacy code reported
# w_hat L_hat / p_hat[n, j] as "sectoral GDP", which is not a sectoral outcome.)

#' Bilateral flows implied by shares and expenditure: F[n, i, j] = pi[n, i, j] X[n, j].
implied_flows <- function(pi, X) {
  out <- pi
  for (j in seq_len(dim(pi)[3])) out[, , j] <- pi[, , j] * X[, j]
  out
}

#' Region-level results (percent changes).
summarise_regions <- function(sol, base) {
  flows0 <- implied_flows(base$pi, base$X)
  flows1 <- implied_flows(sol$pi, sol$X)
  # Trade with all other regions (margin 1: imports, margin 2: exports).
  offdiag <- function(flows, margin) {
    tot <- apply(flows, margin, sum)
    own <- sapply(seq_along(base$regions), function(n) sum(flows[n, n, ]))
    tot - own
  }
  dom <- base$domestic
  # Interprovincial exports plus imports of each Canadian region.
  ip <- function(flows) {
    sapply(base$regions, function(r) {
      if (!r %in% dom) return(NA_real_)
      others <- setdiff(dom, r)
      sum(flows[others, r, ]) + sum(flows[r, others, ])
    })
  }
  pct <- function(x) 100 * (x - 1)
  tibble(
    region = base$regions,
    real_income = pct((sol$I / base$I) / sol$P_hat),
    real_income_per_capita = pct((sol$I / base$I) / (sol$L_hat * sol$P_hat)),
    real_wage = pct(sol$w_hat / sol$P_hat),
    price_index = pct(sol$P_hat),
    nominal_wage = pct(sol$w_hat),
    population = pct(sol$L_hat),
    value_added = pct(sol$VA / base$VA),
    exports = pct(offdiag(flows1, 2) / offdiag(flows0, 2)),
    imports = pct(offdiag(flows1, 1) / offdiag(flows0, 1)),
    interprovincial_trade = pct(ip(flows1) / ip(flows0)),
    tariff_revenue_share = 100 * sol$tariff_revenue / sol$I
  )
}

#' Weights used to aggregate provincial outcomes to Canada.
#'
#' "income": baseline nominal income shares; "population": population shares;
#' "real_income": baseline income deflated by the inter-city price index
#' (table 18-10-0003-01; latest year not after the calibration year).
canada_weights <- function(base, cfg) {
  dom <- base$domestic
  type <- cfg$aggregation$canada_weights %||% "income"
  w <- switch(type,
    income = base$I[dom],
    population = base$population[dom],
    real_income = base$I[dom] / spatial_price_levels(cfg, dom),
    stopf("Unknown aggregation$canada_weights: %s", type))
  w / sum(w)
}

#' Province-level price levels from the inter-city price index.
#'
#' The index compares cities within a year (it is not comparable over time);
#' provinces with two cities take the average. For each region the latest year
#' not after the calibration year is used (the table ends in 2019). Regions
#' never covered (Iqaluit has no all-items index) use the region given in
#' aggregation$price_index_fallback (default: Nunavut uses the Northwest
#' Territories, as in the legacy code).
spatial_price_levels <- function(cfg, regions) {
  names_map <- statcan_name_to_region()
  # Cities are named "<city>, <province>"; Ottawa-Gatineau is reported as
  # "Ottawa-Gatineau, Ontario part, Ontario/Quebec".
  sp <- read_spatial_prices(cfg) |>
    mutate(province = if_else(grepl("Ontario part", city), "Ontario", sub("^.*, ", "", city)),
           region = unname(names_map[province])) |>
    group_by(region, year) |>
    summarise(index = mean(index), .groups = "drop")
  pick <- function(r) {
    s <- sp |> filter(region == r)
    if (nrow(s) == 0) return(c(index = NA_real_, year = NA_real_))
    s <- if (any(s$year <= cfg$years$target)) s |> filter(year <= cfg$years$target) else s
    s <- s |> filter(year == max(year))
    c(index = s$index, year = s$year)
  }
  fallback <- cfg$aggregation$price_index_fallback %||% list(NU = "NT")
  out <- setNames(rep(NA_real_, length(regions)), regions)
  for (r in regions) {
    p <- pick(r)
    if (is.na(p["index"]) && !is.null(fallback[[r]])) {
      p <- pick(fallback[[r]])
      log_info(sprintf("No inter-city price index for %s; using %s.", r, fallback[[r]]))
    }
    if (!is.na(p["year"]) && p["year"] != cfg$years$target) {
      log_info(sprintf("Inter-city price index for %s from %d (calibration year %d).", r,
                       as.integer(p["year"]), cfg$years$target))
    }
    out[r] <- p["index"]
  }
  if (anyNA(out)) stopf("No inter-city price index for: %s", paste(regions[is.na(out)], collapse = ", "))
  out
}

#' Canada-wide aggregates.
summarise_canada <- function(region_table, base, cfg) {
  w <- canada_weights(base, cfg)
  dom <- base$domestic
  rt <- region_table |> filter(region %in% dom)
  wpop <- base$population[dom] / sum(base$population[dom])
  tibble(
    measure = c("real_income", "real_income_per_capita", "real_wage"),
    weights = c(cfg$aggregation$canada_weights %||% "income", "population", "population"),
    change_pct = c(sum(w[rt$region] * rt$real_income),
                   sum(wpop[rt$region] * rt$real_income_per_capita),
                   sum(wpop[rt$region] * rt$real_wage))
  )
}

#' Sector-level results by region (percent changes).
summarise_sectors <- function(sol, base) {
  R_hat <- sol$R / base$R
  emp_share <- base$phi * base$R / base$VA
  expand.grid(region = base$regions, sector = base$sectors, stringsAsFactors = FALSE) |>
    tibble::as_tibble() |>
    mutate(
      baseline_output = as.vector(base$R),
      baseline_employment_share = as.vector(emp_share),
      gross_output = as.vector(100 * (R_hat - 1)),
      employment = as.vector(100 * (sweep(R_hat, 1, sol$w_hat, "/") - 1)),
      producer_price_index = as.vector(100 * (sol$c_hat - 1))
    ) |>
    filter(baseline_output > 0)
}

#' Write all result tables of one scenario to an output folder.
write_scenario_results <- function(sol, base, cfg, dir) {
  ensure_dir(dir)
  regions <- summarise_regions(sol, base)
  canada <- summarise_canada(regions, base, cfg)
  sectors <- summarise_sectors(sol, base)
  write_table(regions, file.path(dir, "regions.csv"))
  write_table(canada, file.path(dir, "canada.csv"))
  write_table(sectors, file.path(dir, "sectors.csv"))
  list(regions = regions, canada = canada, sectors = sectors)
}

#' Render a data frame as a GitHub-flavoured markdown table.
markdown_table <- function(df) {
  fmt <- function(x) if (is.numeric(x)) formatC(x, format = "f", digits = 2) else as.character(x)
  cells <- vapply(df, fmt, character(nrow(df)))
  if (is.null(dim(cells))) cells <- matrix(cells, nrow = 1)
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(ifelse(vapply(df, is.numeric, logical(1)), "---:", ":---"), collapse = "|"), "|")
  body <- apply(cells, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  c(header, sep, body)
}

#' Long table from a matrix or array with dimnames.
array_to_long <- function(x, names) {
  tibble::as_tibble(as.data.frame(as.table(x), stringsAsFactors = FALSE)) |> setNames(names)
}

#' Format a region table for printing.
format_region_table <- function(regions, digits = 2) {
  regions |>
    select(region, real_income, real_income_per_capita, real_wage, price_index,
           population, interprovincial_trade) |>
    mutate(across(-region, \(x) round(x, digits)))
}
