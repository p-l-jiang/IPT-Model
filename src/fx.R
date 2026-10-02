# Exchange rates.
#
# data/raw/fx/FXUSDCAD.csv is the Bank of Canada daily series FXUSDCAD
# (Canadian dollars per US dollar), downloaded from the Bank's Valet API:
#   https://www.bankofcanada.ca/valet/observations/FXUSDCAD/csv

#' Annual-average CAD per USD exchange rates.
#'
#' @return Tibble: year, cad_per_usd, n_days. Years with fewer than 200 daily
#'   observations (e.g. 2007, where the file starts in May) are flagged by
#'   `partial = TRUE`.
load_fx <- function(cfg) {
  raw <- readr::read_csv(cfg$paths$fx_file, show_col_types = FALSE, col_types = "cd")
  names(raw) <- c("date", "value")
  raw |>
    mutate(date = as.Date(date, format = "%m/%d/%Y"), year = as.integer(format(date, "%Y"))) |>
    filter(!is.na(value)) |>
    group_by(year) |>
    summarise(cad_per_usd = mean(value), n_days = n(), .groups = "drop") |>
    mutate(partial = n_days < 200)
}

#' Annual-average CAD per USD for one year (errors if missing or partial).
fx_rate <- function(fx, year) {
  row <- fx[fx$year == year, ]
  if (nrow(row) != 1) stopf("No exchange rate for %d in the FX file.", year)
  if (row$partial) stopf("Exchange-rate data for %d cover only %d days.", year, row$n_days)
  row$cad_per_usd
}
