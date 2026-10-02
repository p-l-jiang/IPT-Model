# Production and demand parameters by region and sector.
#
#   phi[n, j]      value-added share of gross output of sector j in region n
#   gamma[n, k, j] share of input sector k in the intermediate-input bill of
#                  sector j in region n (sums to one over k)
#   beta[n, j]     share of sector j in final demand of region n
#
# Provinces and territories: provincial supply and use tables (15-602-X),
# detail level, basic prices. United States and rest of the world: OECD ICIO.
# Net taxes on products paid on intermediate inputs are part of (1 - phi) and
# are allocated across inputs in proportion to gamma.

# Final-demand columns of the provincial use tables, by code prefix:
# household, NPISH and government consumption, gross fixed capital formation
# (construction, machinery and equipment, intellectual property) and changes in
# inventories.
final_demand_prefixes <- c("PEC", "CEN", "CEG", "COB", "COG", "COH", "CON",
                           "MEB", "MEG", "MEN", "IPB", "IPG", "IPN", "INV")

#' Sector-level production and demand aggregates from one year of SUTs.
#'
#' @return Tibble with one row per region (incl. "CAN" for Canada) and
#'   (input or output) sector: type in {"output","va","input","final"}.
sut_aggregates <- function(cfg, year) {
  sut <- read_sut(cfg, year)
  to_region <- statcan_name_to_region()
  sut <- sut |>
    mutate(region = if_else(geo == "Canada", "CAN", unname(to_region[geo]))) |>
    filter(region %in% c("CAN", cfg$regions$domestic))

  is_industry <- grepl("^(BS|GS|NP)", sut$industry)
  ind_sector <- rep(NA_character_, nrow(sut))
  ind_sector[is_industry] <- to_model_sector(industry_code_to_base_sector(sut$industry[is_industry]), cfg)
  check_mapped(sut$industry[is_industry], ind_sector[is_industry], "SUT industry")

  prod_base <- product_code_to_base_sector(sut$product)
  check_mapped(sut$product, prod_base, "SUT product")
  prod_sector <- ifelse(prod_base == "EXCLUDE", NA_character_, to_model_sector(prod_base, cfg))
  sut$ind_sector <- ind_sector
  sut$prod_sector <- prod_sector
  is_final <- substr(sut$industry, 1, 3) %in% final_demand_prefixes

  output <- sut |>
    filter(table == "Supply", !is.na(ind_sector), !is.na(prod_sector)) |>
    group_by(region, sector = ind_sector) |>
    summarise(value = sum(value), .groups = "drop") |>
    mutate(type = "output", input_sector = NA_character_)
  va <- sut |>
    filter(table == "Use", !is.na(ind_sector), product == "GVA") |>
    group_by(region, sector = ind_sector) |>
    summarise(value = sum(value), .groups = "drop") |>
    mutate(type = "va", input_sector = NA_character_)
  inputs <- sut |>
    filter(table == "Use", !is.na(ind_sector), !is.na(prod_sector)) |>
    group_by(region, input_sector = prod_sector, sector = ind_sector) |>
    summarise(value = sum(value), .groups = "drop") |>
    mutate(type = "input")
  final <- sut |>
    filter(table == "Use", is_final, !is.na(prod_sector)) |>
    group_by(region, sector = prod_sector) |>
    summarise(value = sum(value), .groups = "drop") |>
    mutate(type = "final", input_sector = NA_character_)
  bind_rows(output, va, inputs, final)
}

#' Same aggregates from an aggregated ICIO year (see aggregate_icio()).
icio_aggregates <- function(icio, regions) {
  bind_rows(
    icio$production |> filter(region %in% regions) |>
      transmute(region, sector, value = output, type = "output", input_sector = NA_character_),
    icio$production |> filter(region %in% regions) |>
      transmute(region, sector, value = va, type = "va", input_sector = NA_character_),
    icio$inputs |> filter(region %in% regions) |>
      transmute(region, input_sector, sector, value, type = "input"),
    icio$final_demand |> filter(region %in% regions) |>
      transmute(region, sector, value, type = "final", input_sector = NA_character_)
  )
}

#' Convert aggregates to parameter arrays for a set of regions.
#'
#' Sectors with no output in a region take the value-added share and input
#' structure of `fallback_region` (Canada for provinces and territories).
parameters_from_aggregates <- function(agg, regions, sectors, fallback = NULL) {
  N <- length(regions)
  J <- length(sectors)
  phi <- matrix(NA_real_, N, J, dimnames = list(regions, sectors))
  gamma <- array(NA_real_, c(N, J, J), dimnames = list(regions, input = sectors, user = sectors))
  beta <- matrix(0, N, J, dimnames = list(regions, sectors))

  get <- function(r, ty) agg |> filter(region == r, type == ty)
  for (r in regions) {
    out <- get(r, "output")
    va <- get(r, "va")
    o <- setNames(rep(0, J), sectors)
    o[out$sector] <- out$value
    v <- setNames(rep(0, J), sectors)
    v[va$sector] <- va$value
    phi[r, ] <- ifelse(o > 0, v / o, NA_real_)

    inp <- get(r, "input") |>
      group_by(input_sector, sector) |>
      summarise(value = sum(value), .groups = "drop")
    u <- matrix(0, J, J, dimnames = list(sectors, sectors))
    u[cbind(match(inp$input_sector, sectors), match(inp$sector, sectors))] <- inp$value
    u <- pmax(u, 0)
    cs <- colSums(u)
    gamma[r, , ] <- sweep(u, 2, ifelse(cs > 0, cs, NA_real_), "/")

    fd <- get(r, "final")
    f <- setNames(rep(0, J), sectors)
    f[fd$sector] <- fd$value
    f <- pmax(f, 0)
    beta[r, ] <- f / sum(f)
  }

  if (!is.null(fallback)) {
    for (r in regions) {
      miss <- is.na(phi[r, ]) | is.na(colSums(gamma[r, , ]))
      phi[r, miss] <- fallback$phi[miss]
      gamma[r, , miss] <- fallback$gamma[, miss]
    }
  }
  # A value-added share must lie strictly inside (0, 1] for the solver; clamp
  # data artefacts (e.g. negative value added in a small sector) and record them.
  clamped <- which(!is.na(phi) & (phi <= 0.01 | phi > 1), arr.ind = TRUE)
  phi[] <- pmin(pmax(phi, 0.01), 1)
  list(phi = phi, gamma = gamma, beta = beta, clamped_phi = clamped)
}

#' Build phi, gamma and beta for all model regions.
#'
#' @param icio Aggregated ICIO year in CAD (load_icio_year()).
#' @return List with phi [N x J], gamma [N x J x J], beta [N x J], and
#'   `aggregates` (long tibble of the underlying levels, CAD millions).
build_io_parameters <- function(cfg, year, icio) {
  regions <- model_regions(cfg)
  sectors <- model_sectors(cfg)
  dom <- cfg$regions$domestic
  foreign <- cfg$regions$foreign

  sut <- sut_aggregates(cfg, year)
  ico <- icio_aggregates(icio, c(foreign, "CAN"))

  # Canada-wide parameters from the national SUT, used as a fallback for
  # sectors that do not exist in a province or territory.
  can <- parameters_from_aggregates(sut, "CAN", sectors)
  can_fb <- list(phi = can$phi["CAN", ], gamma = can$gamma["CAN", , ])

  dom_par <- parameters_from_aggregates(sut, dom, sectors, fallback = can_fb)
  for_par <- parameters_from_aggregates(ico, foreign, sectors)
  for (r in foreign) {
    miss <- is.na(for_par$phi[r, ])
    if (any(miss)) stopf("ICIO has no output for %s in sectors: %s", r,
                         paste(sectors[miss], collapse = ", "))
  }

  phi <- rbind(dom_par$phi, for_par$phi)[regions, , drop = FALSE]
  beta <- rbind(dom_par$beta, for_par$beta)[regions, , drop = FALSE]
  gamma <- array(NA_real_, c(length(regions), length(sectors), length(sectors)),
                 dimnames = list(regions, input = sectors, user = sectors))
  gamma[dom, , ] <- dom_par$gamma[dom, , , drop = FALSE]
  gamma[foreign, , ] <- for_par$gamma[foreign, , , drop = FALSE]

  source <- cfg$io_parameters$source
  if (source == "national") {
    # Canada-wide coefficients for every province (Albrecht and Tombe, 2016).
    for (r in dom) {
      phi[r, ] <- pmin(pmax(can$phi["CAN", ], 0.01), 1)
      gamma[r, , ] <- can$gamma["CAN", , ]
      beta[r, ] <- can$beta["CAN", ]
    }
  } else if (source == "global") {
    # Legacy behaviour: world-average phi and gamma for all regions.
    world <- parameters_from_aggregates(
      ico |> mutate(region = "WLD") |>
        group_by(region, type, input_sector, sector) |>
        summarise(value = sum(value), .groups = "drop"),
      "WLD", sectors)
    for (r in regions) {
      phi[r, ] <- world$phi["WLD", ]
      gamma[r, , ] <- world$gamma["WLD", , ]
    }
  }

  assert_finite(phi, "phi")
  assert_finite(gamma, "gamma")
  assert_finite(beta, "beta")
  list(phi = phi, gamma = gamma, beta = beta,
       aggregates = bind_rows(sut |> mutate(source = "SUT"),
                              ico |> mutate(source = "ICIO")),
       clamped_phi = rbind(dom_par$clamped_phi, for_par$clamped_phi))
}

#' Total value added by region (CAD millions): provinces from the SUT, foreign
#' regions from the ICIO.
data_value_added <- function(io, cfg) {
  agg <- io$aggregates
  regions <- model_regions(cfg)
  va <- agg |>
    filter(type == "va",
           (source == "SUT" & region %in% cfg$regions$domestic) |
             (source == "ICIO" & region %in% cfg$regions$foreign)) |>
    group_by(region) |>
    summarise(va = sum(value), .groups = "drop")
  setNames(va$va[match(regions, va$region)], regions)
}
