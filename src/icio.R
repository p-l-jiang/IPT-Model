# OECD Inter-Country Input-Output (ICIO) tables, 2025 edition (extended version).
#
# Layout of each yearly CSV (current USD millions, basic prices):
#   rows:    <country>_<industry> (85 x 50), then TLS (taxes less subsidies on
#            products), VA (value added) and OUT (output);
#   columns: <country>_<industry> intermediate use (85 x 50), then
#            <country>_<HFCE|NPISH|GGFC|GFCF|INVNT|DPABR> final demand
#            (81 x 6), then OUT.
# In the extended version China and Mexico are split into CN1/CN2 and
# MX1/MX2 for intermediate use, value added and output; the CHN_* and MEX_*
# rows and intermediate-use columns are all zero, while final demand is
# reported for CHN and MEX. All of these belong to the rest of the world.

#' Read one year of the ICIO table as a numeric matrix with dimnames.
read_icio <- function(cfg, year) {
  path <- icio_path(cfg, year)
  if (!file.exists(path)) {
    stopf(paste0("ICIO table for %d not found at %s. Download the OECD ICIO 2025 edition ",
                 "(https://oe.cd/icio, 'extended' CSV files) and save the %d table at that path."),
          year, path, year)
  }
  dt <- data.table::fread(path, showProgress = FALSE)
  m <- as.matrix(dt[, -1, with = FALSE])
  rownames(m) <- dt[[1]]
  storage.mode(m) <- "double"
  m
}

#' Map ICIO country codes to model regions.
#'
#' @param countries ICIO country codes (e.g. "USA", "CN1", "ROW").
#' @param foreign Model's foreign regions: c("USA", "ROW") or "ROW".
#' @return "CAN" for Canada, otherwise "USA" or "ROW".
icio_country_to_region <- function(countries, foreign) {
  out <- rep("ROW", length(countries))
  out[countries == "CAN"] <- "CAN"
  if ("USA" %in% foreign) out[countries == "USA"] <- "USA"
  out
}

#' Aggregate an ICIO matrix to model regions (CAN, USA, ROW) and sectors.
#'
#' @return A list of long tibbles in USD millions:
#'   flows        origin, dest, sector, value  (intermediate + final use of
#'                origin's sector output by dest);
#'   inputs       region, input_sector, sector, value (intermediate inputs used
#'                by region's sector, from all origins);
#'   final_demand region, sector, value (final demand for sector output, from
#'                all origins);
#'   production   region, sector, output, va.
aggregate_icio <- function(m, cfg) {
  rows <- rownames(m)
  ind_rows <- rows[!rows %in% c("TLS", "VA", "OUT")]
  z_cols <- intersect(colnames(m), ind_rows)
  fd_cols <- setdiff(colnames(m), c(z_cols, "OUT"))
  if (length(z_cols) != length(ind_rows)) stopf("Unexpected ICIO layout: intermediate rows and columns differ.")

  # "<region>|<sector>" label for each country-industry code.
  region_sector_group <- function(codes) {
    country <- sub("_.*$", "", codes)
    industry <- sub("^[^_]+_", "", codes)
    base <- icio_code_to_base_sector(industry)
    check_mapped(industry, base, "ICIO industry")
    paste(icio_country_to_region(country, cfg$regions$foreign), to_model_sector(base, cfg), sep = "|")
  }
  row_group <- region_sector_group(ind_rows)
  col_group <- region_sector_group(z_cols)
  fd_region <- icio_country_to_region(sub("_.*$", "", fd_cols), cfg$regions$foreign)

  z_rows <- rowsum(m[ind_rows, z_cols], row_group, reorder = FALSE)
  z_agg <- t(rowsum(t(z_rows), col_group, reorder = FALSE))
  fd_rows <- rowsum(m[ind_rows, fd_cols], row_group, reorder = FALSE)
  fd_agg <- t(rowsum(t(fd_rows), fd_region, reorder = FALSE))

  long <- function(mat, col_name) {
    tibble::as_tibble(as.data.frame(as.table(mat), stringsAsFactors = FALSE)) |>
      setNames(c("row", col_name, "value"))
  }
  split_group <- function(df, col, prefix) {
    parts <- strsplit(df[[col]], "|", fixed = TRUE)
    df[[paste0(prefix, "region")]] <- vapply(parts, `[`, "", 1)
    df[[paste0(prefix, "sector")]] <- vapply(parts, `[`, "", 2)
    df
  }

  z_long <- long(z_agg, "col") |> split_group("row", "o_") |> split_group("col", "d_")
  fd_long <- long(fd_agg, "d_region") |> split_group("row", "o_")

  flows <- bind_rows(
    z_long |> select(origin = o_region, dest = d_region, sector = o_sector, value),
    fd_long |> select(origin = o_region, dest = d_region, sector = o_sector, value)
  ) |>
    group_by(origin, dest, sector) |>
    summarise(value = sum(value), .groups = "drop")

  inputs <- z_long |>
    group_by(region = d_region, input_sector = o_sector, sector = d_sector) |>
    summarise(value = sum(value), .groups = "drop")

  final_demand <- fd_long |>
    group_by(region = d_region, sector = o_sector) |>
    summarise(value = sum(value), .groups = "drop")

  production <- tibble(
    group = col_group,
    output = m["OUT", z_cols],
    va = m["VA", z_cols]
  ) |>
    group_by(group) |>
    summarise(output = sum(output), va = sum(va), .groups = "drop") |>
    split_group("group", "") |>
    select(region, sector, output, va)

  list(flows = flows, inputs = inputs, final_demand = final_demand, production = production)
}

#' Convert all value columns of an aggregated ICIO list from USD to CAD.
icio_to_cad <- function(icio_agg, cad_per_usd) {
  lapply(icio_agg, function(df) {
    num <- vapply(df, is.numeric, logical(1))
    df[num] <- lapply(df[num], function(v) v * cad_per_usd)
    df
  })
}

#' Read, aggregate and convert one ICIO year (CAD millions).
load_icio_year <- function(cfg, year, fx) {
  log_info("Aggregating ICIO ", year, " ...")
  agg <- aggregate_icio(read_icio(cfg, year), cfg)
  icio_to_cad(agg, fx_rate(fx, year))
}
