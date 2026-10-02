# Concordances between source classifications and the model's regions/sectors.
#
# All source classifications are first mapped to the 37 "base" sectors in
# config/concordances/sectors.csv (an aggregation of the 50 ICIO 2025 industries
# defined on ISIC Rev. 4). A configuration may then aggregate the base sectors
# into a coarser scheme (e.g. the 22 sectors of Albrecht and Tombe, 2016).

concordance_path <- function(file) file.path(ipt_root(), "config", "concordances", file)

#' Base (37-sector) definitions.
load_base_sectors <- function() {
  readr::read_csv(concordance_path("sectors.csv"), show_col_types = FALSE,
                  col_types = readr::cols(.default = "c", goods = "l"))
}

#' Mapping from base sectors to the model's sector scheme.
#'
#' @return Tibble with columns base_sector, sector_id, sector_name, goods. The
#'   order of the rows defines the model's sector order.
load_sector_scheme <- function(cfg) {
  base <- load_base_sectors()
  scheme <- cfg$sectors$scheme %||% "base37"
  if (identical(scheme, "base37")) {
    return(base |>
      transmute(base_sector = sector_id, sector_id, sector_name, goods))
  }
  map <- readr::read_csv(scheme, show_col_types = FALSE,
                         col_types = readr::cols(.default = "c", goods = "l"))
  missing <- setdiff(base$sector_id, map$base_sector)
  if (length(missing) > 0) stopf("Sector scheme %s does not map base sectors: %s",
                                 scheme, paste(missing, collapse = ", "))
  map
}

#' Model sector IDs in model order.
model_sectors <- function(cfg) unique(load_sector_scheme(cfg)$sector_id)

#' Logical vector (named by sector) flagging goods-producing sectors.
goods_sectors <- function(cfg) {
  s <- load_sector_scheme(cfg) |> distinct(sector_id, goods)
  setNames(s$goods, s$sector_id)
}

#' Map base-sector IDs to model sector IDs.
to_model_sector <- function(base_sector, cfg) {
  scheme <- load_sector_scheme(cfg)
  scheme$sector_id[match(base_sector, scheme$base_sector)]
}

#' Map Statistics Canada product codes (IOPC, e.g. "MPG336111") to base sectors.
#'
#' Returns "EXCLUDE" for codes that are not traded products (taxes, primary
#' inputs, fictive commodities) and NA for codes not covered by any rule.
product_code_to_base_sector <- function(codes) {
  rules <- readr::read_csv(concordance_path("product_prefix_to_sector.csv"),
                           show_col_types = FALSE, col_types = "ccc")
  match_longest_prefix(codes, rules$prefix, rules$sector_id)
}

#' Map Statistics Canada industry codes (IOIC, e.g. "BS336110") to base sectors.
industry_code_to_base_sector <- function(codes) {
  rules <- readr::read_csv(concordance_path("industry_prefix_to_sector.csv"),
                           show_col_types = FALSE, col_types = "ccc")
  match_longest_prefix(codes, rules$prefix, rules$sector_id)
}

#' Map ICIO 2025 industry codes (e.g. "C29") to base sectors.
icio_code_to_base_sector <- function(codes) {
  map <- readr::read_csv(concordance_path("icio_industry_to_sector.csv"),
                         show_col_types = FALSE, col_types = "cccc")
  map$sector_id[match(codes, map$icio_code)]
}

#' Stop with an informative message if some codes are unmapped.
check_mapped <- function(codes, sectors, what) {
  bad <- unique(codes[is.na(sectors)])
  if (length(bad) > 0) {
    stopf("%d %s code(s) have no sector mapping; extend the concordance in config/concordances/: %s",
          length(bad), what, paste(utils::head(bad, 20), collapse = ", "))
  }
  invisible(TRUE)
}

#' Region definitions (codes, names, StatCan names, province codes).
load_regions <- function() {
  readr::read_csv(concordance_path("regions.csv"), show_col_types = FALSE,
                  col_types = "ccccc")
}

#' Named vector translating StatCan geography names to region codes.
statcan_name_to_region <- function() {
  r <- load_regions() |> filter(!is.na(statcan_name))
  setNames(r$region_id, r$statcan_name)
}

#' Symmetric adjacency indicator for pairs of regions.
#'
#' @return Function f(a, b) returning 1 when regions a and b share a border or a
#'   fixed link (see config/concordances/adjacency.csv) and 0 otherwise.
adjacency_function <- function() {
  adj <- readr::read_csv(concordance_path("adjacency.csv"), show_col_types = FALSE,
                         col_types = "cccc")
  keys <- c(paste(adj$region_a, adj$region_b), paste(adj$region_b, adj$region_a))
  function(a, b) as.integer(paste(a, b) %in% keys)
}
