# Sectoral trade elasticities (theta).
#
# Two methods:
#   * "boc2018_rule": derived from Table 1 of Charbonneau and Landry (2018,
#     Bank of Canada Staff Analytical Note 2018-29). For each component BoC
#     sector the 2016 estimate is used when it is statistically significant
#     (|theta / s.e.| >= significance_z), otherwise the Caliendo and Parro
#     (2015) 1993 estimate reported in the same table. Model sectors with
#     several components take the simple average. An additive adjustment
#     (default +2, so that the average elasticity is close to 10) is then
#     applied. Sectors without a BoC component (services) receive
#     services_theta + adjustment.
#   * "fixed": values read from a CSV (columns sector_id, theta).

#' Derive the BoC-rule elasticities, returning the full audit table.
derive_boc_elasticities <- function(te) {
  src <- readr::read_csv(te$source_table, show_col_types = FALSE)
  comp <- readr::read_csv(te$components, show_col_types = FALSE,
                          col_types = readr::cols(.default = "c"))
  z <- te$significance_z %||% 1.96
  adj <- te$adjustment %||% 0
  src <- src |>
    mutate(t_stat = theta_2016 / se_2016,
           significant = abs(t_stat) >= z,
           theta_rule = if_else(significant, theta_2016, theta_1993))
  rows <- lapply(seq_len(nrow(comp)), function(k) {
    parts <- comp$boc_components[k]
    if (is.na(parts) || parts == "") {
      return(tibble(sector_id = comp$sector_id[k], boc_components = NA_character_,
                    detail = sprintf("services value %.2f", te$services_theta),
                    theta_base = te$services_theta))
    }
    parts <- trimws(strsplit(parts, ";", fixed = TRUE)[[1]])
    s <- src[match(parts, src$boc_sector), ]
    if (anyNA(s$boc_sector)) stopf("Unknown BoC sector(s) for %s: %s", comp$sector_id[k],
                                   paste(parts[is.na(s$boc_sector)], collapse = ", "))
    detail <- sprintf("%s: theta2016 = %.1f (s.e. %.1f, t = %.2f) -> %s %.1f", s$boc_sector,
                      s$theta_2016, s$se_2016, s$t_stat,
                      if_else(s$significant, "theta2016", "theta1993"), s$theta_rule)
    tibble(sector_id = comp$sector_id[k], boc_components = paste(parts, collapse = "; "),
           detail = paste(detail, collapse = " | "), theta_base = mean(s$theta_rule))
  })
  bind_rows(rows) |> mutate(adjustment = adj, theta = theta_base + adjustment)
}

#' Trade elasticities for the model's sectors.
#'
#' @return Named numeric vector (sector -> theta); attribute "table" holds the
#'   audit table when derived by rule.
load_trade_elasticities <- function(cfg) {
  te <- cfg$trade_elasticities
  sectors <- model_sectors(cfg)
  if (te$method == "boc2018_rule") {
    tab <- derive_boc_elasticities(te)
    base_theta <- setNames(tab$theta, tab$sector_id)
    scheme <- load_sector_scheme(cfg)
    if (!identical(scheme$base_sector, scheme$sector_id)) {
      stopf("The BoC rule is defined on the 37 base sectors; use method 'fixed' for other schemes.")
    }
    theta <- base_theta[sectors]
    attr(theta, "table") <- tab
  } else if (te$method == "fixed") {
    tab <- readr::read_csv(te$file, show_col_types = FALSE)
    theta <- setNames(tab$theta, tab$sector_id)[sectors]
  } else {
    stopf("Unknown trade_elasticities$method: %s", te$method)
  }
  if (anyNA(theta)) stopf("Missing trade elasticity for: %s",
                          paste(sectors[is.na(theta)], collapse = ", "))
  if (any(theta <= 0)) stopf("Trade elasticities must be positive.")
  theta
}
