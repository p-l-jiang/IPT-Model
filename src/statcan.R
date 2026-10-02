# Download and read Statistics Canada data.
#
# Tables are downloaded as full-table CSV archives from the Statistics Canada
# website and cached under cfg$paths$statcan_cache (git-ignored). Large tables
# are reduced to the rows/columns the model needs and cached as compressed
# extracts so that later runs do not re-read the full files.

statcan_pid <- function(table_id) substr(gsub("-", "", table_id), 1, 8)

#' Download a file with retries (the Statistics Canada servers occasionally
#' reset connections on large downloads).
download_with_retry <- function(url, dest, tries = 5) {
  ensure_dir(dirname(dest))
  old <- options(timeout = max(1800, getOption("timeout")))
  on.exit(options(old))
  for (k in seq_len(tries)) {
    ok <- tryCatch({
      utils::download.file(url, dest, mode = "wb", quiet = TRUE)
      TRUE
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (ok && file.exists(dest) && file.size(dest) > 0) return(invisible(dest))
    Sys.sleep(2^k)
  }
  stopf("Failed to download %s after %d attempts.", url, tries)
}

#' Path to the CSV of a full Statistics Canada table, downloading it if needed.
statcan_table_file <- function(table_id, cfg, refresh = FALSE) {
  pid <- statcan_pid(table_id)
  dir <- ensure_dir(cfg$paths$statcan_cache)
  csv <- file.path(dir, paste0(pid, ".csv"))
  if (file.exists(csv) && !refresh) return(csv)
  zip <- file.path(dir, paste0(pid, "-eng.zip"))
  url <- sprintf("https://www150.statcan.gc.ca/n1/tbl/csv/%s-eng.zip", pid)
  log_info("Downloading Statistics Canada table ", table_id, " ...")
  download_with_retry(url, zip)
  utils::unzip(zip, files = paste0(pid, ".csv"), exdir = dir, overwrite = TRUE)
  unlink(zip)
  csv
}

#' Read selected columns of a Statistics Canada table CSV.
read_statcan_csv <- function(file, select) {
  # VALUE is forced to double: otherwise fread may "bump" the column to
  # integer64 part-way through the file (ignoring integer64 = "double"), and
  # integer64 arithmetic silently rounds, e.g. 16525507 * 1e-3 -> 16526.
  col_classes <- if ("VALUE" %in% select) list(double = "VALUE") else NULL
  dt <- data.table::fread(file, select = select, encoding = "UTF-8", integer64 = "double",
                          colClasses = col_classes, showProgress = FALSE,
                          na.strings = c("", "NA", ".."))
  if (inherits(dt[["VALUE"]], "integer64")) stopf("VALUE was read as integer64 in %s", file)
  # Some files start with a byte-order mark that leaks into the first name.
  names(dt) <- sub("^\\xef\\xbb\\xbf", "", names(dt), useBytes = TRUE)
  tibble::as_tibble(dt)
}

#' Convert a VALUE column to millions of dollars using SCALAR_FACTOR.
to_millions <- function(value, scalar_factor) {
  mult <- c(units = 1e-6, thousands = 1e-3, millions = 1, billions = 1e3)
  f <- mult[scalar_factor]
  if (anyNA(f)) stopf("Unexpected SCALAR_FACTOR: %s",
                      paste(unique(scalar_factor[is.na(f)]), collapse = ", "))
  value * unname(f)
}

#' Cached extract helper: build the extract once with `builder`, then reuse.
cached_extract <- function(cfg, file, builder, refresh = FALSE) {
  path <- file.path(ensure_dir(cfg$paths$statcan_cache), file)
  if (file.exists(path) && !refresh) {
    return(readr::read_csv(path, show_col_types = FALSE, guess_max = 1e5))
  }
  out <- builder()
  readr::write_csv(out, path)
  out
}

#' Interprovincial and international trade flows (table 12-10-0101-01, detail
#' level, basic prices), in millions of dollars.
#'
#' @return Tibble: year, geo (origin, StatCan name), flow (trade flow detail),
#'   product (IOPC code), value.
read_trade_flows_detail <- function(cfg, refresh = FALSE) {
  table_id <- cfg$statcan$trade_flows_table
  cached_extract(cfg, "trade_flows_detail_extract.csv.gz", refresh = refresh, builder = function() {
    raw <- read_statcan_csv(statcan_table_file(table_id, cfg, refresh),
                            select = c("REF_DATE", "GEO", "Trade flow detail", "Product",
                                       "SCALAR_FACTOR", "VALUE"))
    raw |>
      filter(!is.na(VALUE), !Product %in% c("Total products", "Total goods", "Total services")) |>
      transmute(year = as.integer(REF_DATE), geo = GEO, flow = `Trade flow detail`,
                product = extract_code(Product),
                value = to_millions(VALUE, SCALAR_FACTOR))
  })
}

#' Province-level exports to and imports from the United States and all
#' countries, by industry (table 12-10-0100-01, detailed industry level), in
#' millions of dollars. Used to split international trade into USA and ROW.
#'
#' Exports are "Exports" plus "Exports from inventories" (together these equal
#' the "International exports" of table 12-10-0101-01); re-exports are excluded
#' because the trade-flow tables exclude them from international exports.
read_us_trade_shares_source <- function(cfg, refresh = FALSE) {
  table_id <- cfg$statcan$us_trade_table
  cached_extract(cfg, "us_trade_extract.csv.gz", refresh = refresh, builder = function() {
    raw <- read_statcan_csv(statcan_table_file(table_id, cfg, refresh),
                            select = c("REF_DATE", "GEO", "Country Code",
                                       "Value added exports variable", "Industry",
                                       "Aggregation", "SCALAR_FACTOR", "VALUE"))
    raw |>
      filter(Aggregation == "Detailed level",
             `Country Code` %in% c("Total of all countries", "United States"),
             `Value added exports variable` %in% c("Exports", "Exports from inventories", "Imports"),
             !is.na(VALUE)) |>
      transmute(year = as.integer(REF_DATE), geo = GEO,
                partner = if_else(`Country Code` == "United States", "USA", "ALL"),
                direction = if_else(`Value added exports variable` == "Imports", "imports", "exports"),
                industry = extract_code(Industry),
                value = to_millions(VALUE, SCALAR_FACTOR)) |>
      group_by(year, geo, partner, direction, industry) |>
      summarise(value = sum(value), .groups = "drop")
  })
}

#' Population on July 1 (table 17-10-0005-01), all ages, both genders.
read_population <- function(cfg, refresh = FALSE) {
  table_id <- cfg$statcan$population_table
  cached_extract(cfg, "population_extract.csv.gz", refresh = refresh, builder = function() {
    raw <- read_statcan_csv(statcan_table_file(table_id, cfg, refresh),
                            select = c("REF_DATE", "GEO", "Gender", "Age group", "VALUE"))
    raw |>
      filter(Gender == "Total - gender", `Age group` == "All ages", !is.na(VALUE)) |>
      transmute(year = as.integer(REF_DATE), geo = GEO, population = VALUE)
  })
}

#' Inter-city indexes of price differentials, all items (table 18-10-0003-01).
read_spatial_prices <- function(cfg, refresh = FALSE) {
  table_id <- cfg$statcan$price_index_table
  cached_extract(cfg, "spatial_prices_extract.csv.gz", refresh = refresh, builder = function() {
    raw <- read_statcan_csv(statcan_table_file(table_id, cfg, refresh),
                            select = c("REF_DATE", "GEO", "Products and product groups", "VALUE"))
    raw |>
      filter(`Products and product groups` == "All-items", !is.na(VALUE)) |>
      transmute(year = as.integer(REF_DATE), city = GEO, index = VALUE)
  })
}

#' Provincial supply and use tables (catalogue 15-602-X), detail level, basic
#' prices, in millions of dollars.
#'
#' @return Tibble: geo, table ("Supply"/"Use"), industry (code), product (code), value.
read_sut <- function(cfg, year, refresh = FALSE) {
  cached_extract(cfg, sprintf("sut_%d_basic_extract.csv.gz", year), refresh = refresh, builder = function() {
    dir <- ensure_dir(cfg$paths$statcan_cache)
    csv <- file.path(dir, sprintf("SUT_C%d_D.csv", year))
    meta <- file.path(dir, sprintf("SUT_C%d_D_MetaData.csv", year))
    if (!file.exists(csv) || !file.exists(meta) || refresh) {
      zip <- file.path(dir, sprintf("sut_%d.zip", year))
      log_info("Downloading provincial supply and use tables for ", year, " ...")
      download_with_retry(glue_path(cfg$statcan$sut_url, year = year), zip)
      utils::unzip(zip, files = basename(c(csv, meta)), exdir = dir, overwrite = TRUE)
      unlink(zip)
    }
    raw <- read_statcan_csv(csv, select = c("GEO", "Supply and use", "Valuation", "COORDINATE",
                                            "SCALAR_FACTOR", "VALUE")) |>
      filter(Valuation == "Basic price", !is.na(VALUE), VALUE != 0)
    # Older releases omit the classification codes from member names, so codes
    # are taken from the metadata via the member IDs in COORDINATE
    # (geography.supply-use.valuation.industry.product).
    members <- statcan_members(meta)
    ids <- strsplit(raw$COORDINATE, ".", fixed = TRUE)
    code_of <- function(dim_id, k) {
      m <- members[members$dimension == dim_id, ]
      m$code[match(as.integer(vapply(ids, `[`, "", k)), m$member_id)]
    }
    out <- raw |>
      mutate(industry = code_of(4, 4), product = code_of(5, 5)) |>
      transmute(geo = GEO, table = `Supply and use`, industry, product,
                value = to_millions(VALUE, SCALAR_FACTOR))
    if (anyNA(out$industry) || anyNA(out$product)) stopf("Unresolved member codes in %s", csv)
    out
  })
}

#' Members (ID, name, classification code) of every dimension of a Statistics
#' Canada table, from its *_MetaData.csv file.
statcan_members <- function(meta_file) {
  # Encodings differ across releases (UTF-8 with a byte-order mark, Latin-1);
  # only the ASCII IDs and codes are used, so lines are read as bytes.
  lines <- readLines(meta_file, warn = FALSE)
  lines[1] <- sub("^\\xef\\xbb\\xbf", "", lines[1], useBytes = TRUE)
  lines <- iconv(lines, from = "latin1", to = "UTF-8")
  start <- grep("^\"?Dimension ID\"?,\"?Member Name\"?", lines)
  if (length(start) != 1) stopf("Cannot find the member list in %s", meta_file)
  end <- start + which(lines[(start + 1):length(lines)] == "")[1] - 1
  if (is.na(end)) end <- length(lines)
  m <- utils::read.csv(text = paste(lines[start:end], collapse = "\n"), check.names = FALSE,
                       colClasses = "character")
  # Some releases append footnote rows to the member list; keep proper members only.
  out <- tibble(dimension = suppressWarnings(as.integer(m[["Dimension ID"]])),
                member_id = suppressWarnings(as.integer(m[["Member ID"]])),
                name = m[["Member Name"]], code = gsub("^\\[|\\]$", "", m[["Classification Code"]]))
  out |> filter(!is.na(dimension), !is.na(member_id))
}
