# Bilateral trade flows by sector (CAD millions, basic prices).
#
# Sources
#   * Interprovincial flows, including each province's purchases from itself,
#     and total international exports/imports by province: Statistics Canada
#     table 12-10-0101-01 (detail level, 2010 onward). Products are mapped to
#     sectors by their IOPC codes.
#   * Split of international exports/imports between the United States and the
#     rest of the world: US shares by province, sector and year computed within
#     table 12-10-0100-01 (detailed industry level) and applied to the totals of
#     table 12-10-0101-01.
#   * Flows among the United States and the rest of the world (and their
#     domestic purchases): OECD ICIO, converted to CAD at the annual-average
#     Bank of Canada rate.

#' Domestic (province-to-province) flows and international totals by province.
#'
#' @return List with tibbles `domestic` (year, origin, dest, sector, value),
#'   `exports` (year, origin, sector, value) and `imports` (year, dest, sector, value).
canadian_flows <- function(cfg, years) {
  raw <- read_trade_flows_detail(cfg) |> filter(year %in% years)
  if (nrow(raw) == 0) stopf("No trade-flow data for years %s.", paste(range(years), collapse = "-"))
  base <- product_code_to_base_sector(raw$product)
  check_mapped(raw$product, base, "product")
  to_region <- statcan_name_to_region()
  dom <- cfg$regions$domestic

  flows <- raw |>
    mutate(base_sector = base) |>
    filter(base_sector != "EXCLUDE") |>
    mutate(sector = to_model_sector(base_sector, cfg),
           origin = unname(to_region[geo])) |>
    filter(origin %in% dom)

  n_neg <- sum(flows$value < 0)
  if (n_neg > 0) {
    log_info(sprintf("Setting %d negative product-level flow entries (sum %.1f) to zero.",
                     n_neg, sum(flows$value[flows$value < 0])))
    flows$value <- pmax(flows$value, 0)
  }

  domestic <- flows |>
    filter(startsWith(flow, "To ")) |>
    mutate(dest = unname(to_region[sub("^To ", "", flow)])) |>
    filter(dest %in% dom) |>
    group_by(year, origin, dest, sector) |>
    summarise(value = sum(value), .groups = "drop")
  exports <- flows |>
    filter(flow == "International exports") |>
    group_by(year, origin, sector) |>
    summarise(value = sum(value), .groups = "drop")
  imports <- flows |>
    filter(flow == "International imports") |>
    group_by(year, dest = origin, sector) |>
    summarise(value = sum(value), .groups = "drop")
  list(domestic = domestic, exports = exports, imports = imports)
}

#' Shares of the United States in each province's international exports and
#' imports, by sector and year.
#'
#' Computed from table 12-10-0100-01 as US / all-countries trade within the
#' same table and classification. Missing or zero denominators fall back, in
#' order, to the Canada-wide share for the sector, the province's all-sector
#' share and the Canada-wide all-sector share.
#'
#' @return Tibble: year, region, sector, direction ("exports"/"imports"), us_share.
us_trade_shares <- function(cfg, years) {
  # Rows without an industry code are the "Total industries" aggregate.
  src <- read_us_trade_shares_source(cfg) |> filter(year %in% years, !is.na(industry))
  base <- industry_code_to_base_sector(src$industry)
  check_mapped(src$industry, base, "industry")
  to_region <- statcan_name_to_region()
  src <- src |>
    mutate(sector = to_model_sector(base, cfg),
           region = if_else(geo == "Canada", "CAN", unname(to_region[geo]))) |>
    filter(!is.na(region))

  share_table <- function(df, ...) {
    df |>
      group_by(year, direction, ..., partner) |>
      summarise(value = sum(value), .groups = "drop") |>
      tidyr::pivot_wider(names_from = partner, values_from = value, values_fill = 0) |>
      mutate(share = if_else(ALL > 0, pmin(pmax(USA / ALL, 0), 1), NA_real_)) |>
      select(-USA, -ALL)
  }
  by_region_sector <- share_table(src, region, sector)
  by_region <- share_table(src, region) |> rename(share_region = share)
  canada_sector <- by_region_sector |> filter(region == "CAN") |>
    select(year, direction, sector, share_can_sector = share)
  canada_total <- by_region |> filter(region == "CAN") |>
    select(year, direction, share_can = share_region)

  grid <- tidyr::expand_grid(year = years, region = cfg$regions$domestic,
                             sector = model_sectors(cfg), direction = c("exports", "imports"))
  grid |>
    left_join(by_region_sector, by = c("year", "region", "sector", "direction")) |>
    left_join(canada_sector, by = c("year", "sector", "direction")) |>
    left_join(by_region, by = c("year", "region", "direction")) |>
    left_join(canada_total, by = c("year", "direction")) |>
    mutate(us_share = coalesce(share, share_can_sector, share_region, share_can),
           source = case_when(!is.na(share) ~ "region-sector",
                              !is.na(share_can_sector) ~ "canada-sector",
                              !is.na(share_region) ~ "region",
                              TRUE ~ "canada")) |>
    select(year, region, sector, direction, us_share, source)
}

#' Flows between Canadian regions and the foreign regions.
#'
#' @return Tibble: year, origin, dest, sector, value.
canada_foreign_flows <- function(cfg, can, years) {
  if (!"USA" %in% cfg$regions$foreign) {
    return(bind_rows(
      can$exports |> mutate(dest = "ROW"),
      can$imports |> mutate(origin = "ROW")
    ) |> select(year, origin, dest, sector, value))
  }
  shares <- us_trade_shares(cfg, years)
  exp_sh <- shares |> filter(direction == "exports") |> select(year, origin = region, sector, us_share)
  imp_sh <- shares |> filter(direction == "imports") |> select(year, dest = region, sector, us_share)
  exports <- can$exports |> left_join(exp_sh, by = c("year", "origin", "sector"))
  imports <- can$imports |> left_join(imp_sh, by = c("year", "dest", "sector"))
  bind_rows(
    exports |> mutate(dest = "USA", value = value * us_share),
    exports |> mutate(dest = "ROW", value = value * (1 - us_share)),
    imports |> mutate(origin = "USA", value = value * us_share),
    imports |> mutate(origin = "ROW", value = value * (1 - us_share))
  ) |>
    select(year, origin, dest, sector, value)
}

#' Complete bilateral flow panel.
#'
#' @param years Years of Canadian flows to include.
#' @param icio_years Years for which flows among foreign regions are added
#'   from the ICIO (needed for the calibration year; optional otherwise).
#' @return Tibble: year, origin, dest, sector, value (CAD millions). Only
#'   strictly positive flows are kept.
build_flow_panel <- function(cfg, years, icio_years = integer(0), fx = load_fx(cfg)) {
  log_info("Building Canadian trade flows ...")
  can <- canadian_flows(cfg, years)
  panel <- bind_rows(can$domestic, canada_foreign_flows(cfg, can, years))
  for (y in icio_years) {
    icio <- load_icio_year(cfg, y, fx)
    foreign <- icio$flows |>
      filter(origin %in% cfg$regions$foreign, dest %in% cfg$regions$foreign) |>
      mutate(year = y)
    panel <- bind_rows(panel, foreign)
  }
  panel |>
    group_by(year, origin, dest, sector) |>
    summarise(value = sum(value), .groups = "drop") |>
    filter(value > 0) |>
    arrange(year, origin, dest, sector)
}

#' Years for which the panel contains the full flow matrix, i.e. years in which
#' flows among the foreign regions (from the ICIO) are present.
complete_years <- function(panel) {
  sort(unique(panel$year[panel$origin == "ROW" & panel$dest == "ROW"]))
}
