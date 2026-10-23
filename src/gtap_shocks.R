# Conversion of GTAP shock files into IPT scenarios.
#
# A GTAP shock file (.psh, or the shock statements of a .cmf) sets percentage
# changes in model variables for elements of the GTAP aggregation. Two
# variables are converted:
#
#   tms(i, r, s)  change (%) in the power of the tariff levied by s on imports
#                 of commodity i from r. IPT's baseline has no tariffs, so an
#                 ad valorem tariff t' = tms / 100 reproduces the change in the
#                 power of the tariff exactly: (1 + t') / (1 + 0) = 1 + tms / 100.
#   qxs(i, r, s)  change (%) in the volume of i exported from r to s, used in
#                 GTAP for quantity restrictions (bans, boycotts) with tms
#                 swapped endogenous. IPT has no quantity instruments: the
#                 shock becomes an iceberg cost that lowers the flow by the same
#                 share in partial equilibrium, tau_hat = (1 + q)^(-1 / theta),
#                 and raises no revenue.
#
# Regions. The GTAP region holding Canada maps to every province and territory
# (`domestic`), the United States to USA, and every other GTAP region to ROW.
# Shocks between two GTAP regions that both fall in ROW (e.g. EU tariffs on
# China) cannot be represented and are reported as dropped.
#
# Aggregation. One IPT cell (importer group, exporter group, sector) usually
# contains several GTAP components c = (commodity, exporter, importer): the
# eleven GTAP regions inside ROW, or two GTAP commodities inside one IPT sector
# (steel and non-ferrous metals in BMT). The cell's tariff is the trade-weighted
# average of the components' tariffs, shocked or not,
#
#   t[I, E, j] = sum_c v_c t_c / sum_c v_c,
#
# which preserves the tariff paid on the cell's baseline trade. The weights v_c
# are baseline bilateral trade, from either
#   * the OECD ICIO table of the calibration year, mapped to GTAP regions and
#     commodities by two concordances (the default), or
#   * a GTAP database: a CSV of VCIF (imports at world prices) with columns
#     commodity, exporter, importer, value.

#' Parse the shock statements of a GTAP command or shock file.
#'
#' Comments run from "!" to the end of the line; statements end with ";".
#' Only element-specific shocks, `Shock v("a", "b", ...) = [uniform] x;`, are
#' supported. Other statements (exogenous, swap, ...) are ignored.
#'
#' @return Tibble: variable, commodity, exporter, importer, value (percent).
read_gtap_shocks <- function(path) {
  txt <- sub("!.*$", "", readLines(path, warn = FALSE))
  stmts <- trimws(strsplit(paste(txt, collapse = " "), ";", fixed = TRUE)[[1]])
  stmts <- gsub("\\s+", " ", stmts[nzchar(stmts)])
  shock <- grepl("^shock\\s", stmts, ignore.case = TRUE)
  if (sum(!shock) > 0) log_info(sprintf("Ignoring %d non-shock statement(s) in %s.", sum(!shock), basename(path)))
  stmts <- stmts[shock]
  pat <- "^shock ([A-Za-z_][A-Za-z0-9_@]*) ?\\(([^)]*)\\) ?= ?(uniform )?([-+]?[0-9.]+([eE][-+]?[0-9]+)?)$"
  ok <- grepl(pat, stmts, ignore.case = TRUE, perl = TRUE)
  if (any(!ok)) {
    stopf(paste0("Unsupported shock statement(s) in %s:\n  %s\n",
                 "Only element-specific shocks such as Shock tms(\"c_Steel\", \"Canada\", \"USA\") = 25; are converted."),
          basename(path), paste(stmts[!ok], collapse = "\n  "))
  }
  m <- regmatches(stmts, regexec(pat, stmts, ignore.case = TRUE, perl = TRUE))
  args <- lapply(m, function(x) trimws(strsplit(x[3], ",", fixed = TRUE)[[1]]))
  quoted <- vapply(args, function(a) length(a) == 3 && all(grepl('^"[^"]+"$', a)), logical(1))
  if (any(!quoted)) {
    stopf("Shocks over whole sets or with other than three arguments are not supported:\n  %s",
          paste(stmts[!quoted], collapse = "\n  "))
  }
  args <- lapply(args, function(a) gsub('"', "", a, fixed = TRUE))
  out <- tibble(
    variable = tolower(vapply(m, `[`, "", 2)),
    commodity = vapply(args, `[`, "", 1),
    exporter = vapply(args, `[`, "", 2),
    importer = vapply(args, `[`, "", 3),
    value = as.numeric(vapply(m, `[`, "", 5))
  )
  unsupported <- setdiff(out$variable, c("tms", "qxs"))
  if (length(unsupported) > 0) {
    stopf("Shocks to %s cannot be converted (supported: tms, qxs).", paste(unsupported, collapse = ", "))
  }
  dup <- out |> count(variable, commodity, exporter, importer) |> filter(n > 1)
  if (nrow(dup) > 0) stopf("Element shocked more than once: %s(%s, %s, %s).",
                           dup$variable[1], dup$commodity[1], dup$exporter[1], dup$importer[1])
  both <- inner_join(filter(out, variable == "tms"), filter(out, variable == "qxs"),
                     by = c("commodity", "exporter", "importer"))
  if (nrow(both) > 0) stopf("Both tms and qxs are shocked for (%s, %s, %s).",
                            both$commodity[1], both$exporter[1], both$importer[1])
  out
}

#' Read the GTAP-to-ICIO concordances.
#'
#' @param regions_file CSV with columns icio_country, gtap_region.
#' @param commodities_file CSV with columns icio_industry, gtap_commodity, share
#'   (share of the ICIO industry's trade that belongs to the GTAP commodity;
#'   shares sum to one by industry).
load_gtap_concordances <- function(regions_file, commodities_file, cfg) {
  regions <- readr::read_csv(regions_file, show_col_types = FALSE, col_types = "cc")
  commodities <- readr::read_csv(commodities_file, show_col_types = FALSE,
                                 col_types = readr::cols(.default = "c", share = "d"))
  if (anyDuplicated(regions$icio_country)) stopf("Duplicate ICIO countries in %s.", regions_file)
  bad <- commodities |> group_by(icio_industry) |> summarise(s = sum(share)) |> filter(abs(s - 1) > 1e-9)
  if (nrow(bad) > 0) stopf("Shares in %s must sum to one by ICIO industry (%s).",
                           commodities_file, paste(bad$icio_industry, collapse = ", "))
  sector <- to_model_sector(icio_code_to_base_sector(commodities$icio_industry), cfg)
  check_mapped(commodities$icio_industry, sector, "ICIO industry")
  list(regions = regions, commodities = mutate(commodities, sector = sector))
}

#' Baseline trade weights from the OECD ICIO table.
#'
#' Bilateral trade of each ICIO industry (intermediate plus final use, current
#' USD) is aggregated to GTAP regions and split between GTAP commodities with
#' the concordance shares.
#'
#' @return Tibble: sector, commodity, exporter, importer, value.
icio_gtap_weights <- function(cfg, year, conc) {
  m <- read_icio(cfg, year)
  rows <- rownames(m)[!rownames(m) %in% c("TLS", "VA", "OUT")]
  cols <- setdiff(colnames(m), "OUT")
  dest <- sub("_.*$", "", cols)
  by_dest <- t(rowsum(t(m[rows, cols]), dest, reorder = FALSE))   # [origin code x dest country]
  flows <- tibble::as_tibble(as.data.frame(as.table(by_dest), stringsAsFactors = FALSE)) |>
    setNames(c("code", "dest_country", "value")) |>
    mutate(origin_country = sub("_.*$", "", code), icio_industry = sub("^[^_]+_", "", code)) |>
    filter(value > 0, icio_industry %in% conc$commodities$icio_industry)
  countries <- union(flows$origin_country, flows$dest_country)
  unmapped <- setdiff(countries, conc$regions$icio_country)
  if (length(unmapped) > 0) stopf("ICIO countries without a GTAP region: %s", paste(unmapped, collapse = ", "))
  region_of <- setNames(conc$regions$gtap_region, conc$regions$icio_country)
  flows |>
    mutate(exporter = unname(region_of[origin_country]), importer = unname(region_of[dest_country])) |>
    filter(exporter != importer) |>
    inner_join(conc$commodities, by = "icio_industry", relationship = "many-to-many") |>
    group_by(sector, commodity = gtap_commodity, exporter, importer) |>
    summarise(value = sum(value * share), .groups = "drop")
}

#' Baseline trade weights from a GTAP database export.
#'
#' @param file CSV with columns commodity, exporter, importer, value (VCIF,
#'   imports at world prices; e.g. the Header browser's CSV download of VCIF,
#'   or HARr::read_har("basedata.har")$vcif reshaped to long form).
gtap_csv_weights <- function(file, conc) {
  w <- readr::read_csv(file, show_col_types = FALSE)
  names(w) <- tolower(names(w))
  need <- c("commodity", "exporter", "importer", "value")
  if (!all(need %in% names(w))) stopf("%s must have columns %s.", file, paste(need, collapse = ", "))
  map <- conc$commodities |> distinct(commodity = gtap_commodity, sector)
  w |>
    select(all_of(need)) |>
    filter(exporter != importer) |>
    inner_join(map, by = "commodity", relationship = "many-to-many") |>
    select(sector, commodity, exporter, importer, value)
}

#' IPT region group of each GTAP region.
gtap_to_ipt_region <- function(x, canada = "Canada", usa = "USA") {
  if_else(x == canada, "domestic", if_else(x == usa, "USA", "ROW"))
}

#' Convert parsed GTAP shocks into IPT shocks.
#'
#' @param shocks Output of read_gtap_shocks().
#' @param weights Output of icio_gtap_weights() or gtap_csv_weights().
#' @param theta Named trade elasticities by IPT sector (for qxs shocks).
#' @return List: cells (one row per IPT shock, with the components behind it),
#'   components (weights and rates of every component in a shocked cell) and
#'   dropped (shocks that cannot be represented).
convert_gtap_shocks <- function(shocks, weights, theta, canada = "Canada", usa = "USA") {
  regions <- union(weights$exporter, weights$importer)
  unknown <- setdiff(union(shocks$exporter, shocks$importer), regions)
  if (length(unknown) > 0) stopf("GTAP regions in the shocks but not in the weights: %s", paste(unknown, collapse = ", "))
  if (!canada %in% regions || !usa %in% regions) stopf("Weights must include the regions %s and %s.", canada, usa)
  unknown <- setdiff(shocks$commodity, weights$commodity)
  if (length(unknown) > 0) stopf("GTAP commodities without a concordance entry: %s", paste(unknown, collapse = ", "))

  grp <- function(x) gtap_to_ipt_region(x, canada, usa)
  shocks <- shocks |> mutate(ipt_importer = grp(importer), ipt_exporter = grp(exporter))
  dropped <- shocks |> filter(ipt_importer == ipt_exporter)
  shocks <- shocks |> filter(ipt_importer != ipt_exporter)

  w <- weights |>
    mutate(ipt_importer = grp(importer), ipt_exporter = grp(exporter)) |>
    filter(ipt_importer != ipt_exporter)
  cells_of <- function(var) {
    s <- shocks |> filter(variable == var)
    if (nrow(s) == 0) return(NULL)
    keys <- w |> semi_join(s, by = c("commodity", "exporter", "importer")) |>
      distinct(ipt_importer, ipt_exporter, sector)
    no_trade <- s |> anti_join(filter(w, value > 0), by = c("commodity", "exporter", "importer"))
    if (nrow(no_trade) > 0) {
      warnf("%d %s shock(s) apply to flows with no baseline trade and have no effect, e.g. %s(%s, %s, %s).",
            nrow(no_trade), var, var, no_trade$commodity[1], no_trade$exporter[1], no_trade$importer[1])
    }
    w |>
      semi_join(keys, by = c("ipt_importer", "ipt_exporter", "sector")) |>
      left_join(s |> select(commodity, exporter, importer, value_pct = value),
                by = c("commodity", "exporter", "importer")) |>
      mutate(variable = var, value_pct = coalesce(value_pct, 0))
  }
  comp <- bind_rows(cells_of("tms"), cells_of("qxs")) |>
    group_by(variable, ipt_importer, ipt_exporter, sector) |>
    mutate(weight = value / sum(value)) |>
    ungroup()

  describe <- function(commodity, exporter, importer, value_pct, weight) {
    d <- tibble(commodity, exporter, importer, value_pct, weight) |>
      group_by(commodity) |>
      summarise(pct = sum(weight * value_pct) / sum(weight), shocked = any(value_pct != 0),
                weight = sum(weight), .groups = "drop") |>
      filter(shocked) |>
      arrange(desc(weight))
    paste(sprintf("%s %.2f%% (w %.2f)", d$commodity, d$pct, d$weight), collapse = ", ")
  }
  cells <- comp |>
    group_by(variable, ipt_importer, ipt_exporter, sector) |>
    summarise(change = sum(weight * value_pct) / 100,
              trade_usd_m = sum(value),
              detail = describe(commodity, exporter, importer, value_pct, weight),
              .groups = "drop") |>
    mutate(theta = unname(theta[sector]),
           type = if_else(variable == "tms", "tariff", "iceberg"),
           rate = if_else(variable == "tms", change, NA_real_),
           factor = if_else(variable == "qxs", (1 + change)^(-1 / theta), NA_real_))
  if (any(cells$variable == "qxs" & is.na(cells$theta))) stopf("Missing trade elasticity for a qxs sector.")
  list(cells = cells, components = comp, dropped = dropped)
}

#' Write converted shocks as an IPT scenario file.
#'
#' @param variants List of scenario variants, each a list with id, label and
#'   any scenario-level settings (tariff_treatment, migration_elasticity); all
#'   variants share the same shocks (a YAML anchor).
write_gtap_scenario <- function(conv, path, variants, header = character(0), sector_order = NULL) {
  cells <- conv$cells
  group_label <- c(domestic = "Canada", USA = "the United States", ROW = "the rest of the world")
  region_yaml <- function(x) if (x == "domestic") "domestic" else sprintf('["%s"]', x)
  ord <- c("USA|domestic", "USA|ROW", "domestic|USA", "domestic|ROW", "ROW|USA", "ROW|domestic")
  cells <- cells |>
    mutate(pair = paste(ipt_importer, ipt_exporter, sep = "|"),
           pair_rank = match(pair, ord),
           sector_rank = if (is.null(sector_order)) 0L else match(sector, sector_order)) |>
    arrange(pair_rank, type == "iceberg", sector_rank, sector)
  anchor <- paste0(gsub("[^A-Za-z0-9]", "_", variants[[1]]$id), "_shocks")

  shock_lines <- character(0)
  for (p in unique(cells$pair)) {
    cp <- cells |> filter(pair == p)
    imp <- cp$ipt_importer[1]
    ex <- cp$ipt_exporter[1]
    shock_lines <- c(shock_lines, sprintf("      # Imports of %s from %s", group_label[[imp]], group_label[[ex]]))
    for (k in seq_len(nrow(cp))) {
      r <- cp[k, ]
      value <- if (r$type == "tariff") sprintf("rate: %.6f", r$rate) else sprintf("factor: %.6f", r$factor)
      note <- if (r$type == "tariff") r$detail else
        sprintf("%s; flow change %.2f%%, theta %.1f", r$detail, 100 * r$change, r$theta)
      shock_lines <- c(shock_lines, sprintf("      - {type: %s, importers: %s, exporters: %s, sectors: [%s], %s}   # %s",
                                            r$type, region_yaml(imp), region_yaml(ex), r$sector, value, note))
    }
  }

  out <- c(paste0("# ", header), "", "scenarios:")
  for (k in seq_along(variants)) {
    v <- variants[[k]]
    out <- c(out, sprintf("  - id: %s", v$id), sprintf('    label: "%s"', v$label))
    for (nm in setdiff(names(v), c("id", "label"))) out <- c(out, sprintf("    %s: %s", nm, v[[nm]]))
    if (k == 1) {
      out <- c(out, sprintf("    shocks: &%s", anchor), shock_lines)
    } else {
      out <- c(out, sprintf("    shocks: *%s", anchor))
    }
    out <- c(out, "")
  }
  writeLines(out, path)
  invisible(path)
}
